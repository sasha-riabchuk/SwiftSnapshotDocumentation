# Flow Explorer — Design Spec

**Date:** 2026-05-31
**Status:** Approved (pending implementation plan)
**Component:** SwiftSnapshotDocumentation

## 1. Summary

Add a capability that emits a **static, interactive, multi-feature web bundle**
visualizing each tested feature's screens as a **branching graph** (Cytoscape.js +
dagre), with framed-snapshot thumbnail nodes and a per-screen variants panel.

**Guiding principle — separate data from rendering.** The library emits a neutral
data contract (JSON/JS + images); the Cytoscape bundle is the default *renderer*
over that contract. This keeps the library tool-agnostic (the same data can feed
Graphviz/PlantUML/Figma later), makes the data unit-testable in Swift, and lets the
renderer ship as a vendored static asset.

## 2. Goals / Non-goals

### Goals (v1)
- Export a self-contained, offline, interactive web bundle (no backend, no build step).
- Multi-feature explorer: a sidebar lists every exported feature; pick one to explore.
- Branching flows via explicit, labeled transitions between screens.
- Nodes are framed-snapshot thumbnails + title; clicking a node opens a panel with all
  device × theme variants, description, and callouts.
- Race-safe under parallel test execution.

### Non-goals (v1)
- In-browser editing, live hot-reload, search/filter, explorer theming.
- Cross-*feature* links (a screen in one feature pointing into another).
- Changing the existing DocC `includeFlowDiagram` (Mermaid) output. It stays as-is;
  it may consume the same transitions in a later iteration.

## 3. Data model (new public API)

```swift
public struct ScreenTransition: Sendable, Equatable {
    public let target: String     // target screen's title or id
    public let label: String?     // optional trigger/condition shown on the edge
    public static func to(_ target: String, on label: String? = nil) -> ScreenTransition
}
```

- `DocumentedScreen` gains `transitions: [ScreenTransition]` (default `[]`); it remains
  a `Sendable` metadata record.
- `DocumentedFlow.addScreen(...)` gains `transitions: [ScreenTransition] = []`.

### Edge resolution rules
- Transition `target` resolves against screen `id`s (sanitized titles) at export time.
- **Linear fallback:** if a flow declares *no* transitions on *any* screen, edges fall
  back to add-order (A→B→C). If *any* transition is declared anywhere in the flow, only
  explicit edges are used (no implicit linear edges).
- **Unresolved target:** emit a warning, skip that edge (never fail the export), and
  include it in the returned result's `unresolvedTransitions`.

## 4. Neutral data contract

### Per-feature `flows.js` (assigns a JS global; see §6 for the CORS rationale)
```js
window.FLOW_DATA = window.FLOW_DATA || {};
window.FLOW_DATA["Onboarding"] = {
  "name": "Onboarding",
  "summary": "…",
  "screens": [{
    "id": "login", "title": "Login", "description": "…",
    "thumbnail": "images/02-login-iPhone15Pro-light.png",
    "variants": [{ "device": "iPhone15Pro", "theme": "light", "image": "images/…png" }],
    "callouts": [{ "type": "tip", "content": "…" }]
  }],
  "edges": [
    { "from": "login", "to": "profile-empty", "label": "valid" },
    { "from": "login", "to": "login-error",   "label": "invalid" }
  ]
};
```

### Top-level `manifest.js`
```js
window.FLOW_MANIFEST = { "features": [{ "name": "Onboarding", "dir": "Onboarding" }, …] };
```

- **Thumbnail selection:** the first variant in add order (first device, first theme) is
  the node thumbnail; all variants are available in the panel.
- The underlying objects are plain JSON values, so a `.json` form is trivially derivable
  for power users who want to feed Graphviz/PlantUML/Figma.

## 5. Output layout (static bundle)

```
FlowExplorer/
  index.html         # shell: feature sidebar + Cytoscape canvas + variants panel
  app.js             # renderer (~300 lines): reads globals, builds graph, handles clicks
  vendor/            # cytoscape.min.js, dagre.js, cytoscape-dagre.js (vendored, no build)
  manifest.js        # window.FLOW_MANIFEST = {…}
  Onboarding/
    feature.json     # per-feature marker used to (re)build the manifest
    flows.js         # window.FLOW_DATA["Onboarding"] = {…}
    images/          # framed snapshots (thumbnails + variants)
  Checkout/ …
```

## 6. Rendering / CORS decision

Data is emitted as **JS files that assign globals** (loaded via `<script>` tags), not
JSON fetched at runtime. Browsers block `fetch()` of local files over `file://`, so JS
globals let the bundle work by **double-clicking `index.html`** *and* via a static
server (`python3 -m http.server`). Images load fine over `file://` via `<img>` /
`background-image`.

Renderer behavior:
- `index.html` lists features from `window.FLOW_MANIFEST`.
- Selecting a feature reads `window.FLOW_DATA[name]`, builds Cytoscape nodes
  (`background-image` = thumbnail, label = title) and edges (with labels), runs the
  **dagre** layout (`rankDir: "TB"`), and enables pan/zoom.
- Clicking a node opens a panel with all variants (device × theme), description, callouts.

## 7. API surface

```swift
@discardableResult
public func exportFlowExplorer(
    at explorerPath: String,
    snapshotSourcePath: String? = nil,
    configuration: DocumentationConfiguration? = nil
) async throws -> ExportedFeature

public struct ExportedFeature: Sendable, Equatable {
    public let featurePath: String
    public let screenCount: Int
    public let edgeCount: Int
    public let imageCount: Int
    public let unresolvedTransitions: [String]
}

public enum FlowExplorer {
    /// Rebuilds manifest.js from the feature.json markers present in the directory.
    public static func rebuildManifest(at explorerPath: String) throws
}
```

`exportFlowExplorer` is a **separate method** from `generateDocumentation` (distinct
artifact, distinct concern), but shares the same prerequisite: snapshots must already
have been captured by `addScreen` (iOS-only) or be present on disk as committed
baselines. A flow can call both `generateDocumentation` and `exportFlowExplorer` in the
same test. It: resolves + copies + frames the snapshots into
`<Feature>/images/`, writes `feature.json` + `flows.js`, copies the shell assets
(`index.html`/`app.js`/`vendor/`) if absent or stale, and rebuilds `manifest.js`.

## 8. Reuse / focused refactor

The snapshot **resolve → copy → device-frame composite** logic currently lives inside
`DoCCGenerator`. Extract it into a shared `SnapshotImageCopier` used by both
`DoCCGenerator` and the new `FlowExplorerExporter`, so explorer thumbnails reuse the
same framed images with no duplication. This is the only refactor; nothing unrelated.

## 9. Race-safe multi-feature aggregation

- **Per-feature data is race-free:** each export writes only its own `<Feature>/` folder
  (isolated; no shared-file contention) plus a `<Feature>/feature.json` marker.
- **Manifest is derived:** each export rebuilds `manifest.js` by scanning sibling
  `*/feature.json` markers and writing it atomically. Because it is derived from the
  directory, it self-heals — after a full test run all folders exist and the manifest
  converges.
- **Escape hatch:** `FlowExplorer.rebuildManifest(at:)` guarantees a complete index in a
  single call (e.g. from a final test/teardown) for the rare case of two exports
  finishing in the same instant. This limitation is documented rather than hidden.

## 10. Web assets packaging

Vendored assets ship as SPM package resources on the library target
(`resources: [.copy("Resources/FlowExplorerAssets")]`), read via `Bundle.module` and
written to the output at export time (only when absent or older than the bundled copy).
Adds `Bundle.module` usage to the library target (standard SPM).

## 11. Error handling

- Image side reuses `DocumentationError` (`snapshotsNotFound` / `noSnapshotsCopied` /
  `captureUnavailable`).
- A flow with no screens throws a clear error.
- Unresolved transitions are non-fatal: warning + skipped edge + listed in
  `ExportedFeature.unresolvedTransitions`.

## 12. Testing

- **Data model:** transition→edge resolution; linear fallback when no transitions;
  unresolved target → warning + skipped edge.
- **Exporter (temp snapshot dir):** assert the feature folder, decodable flow data,
  correct edges + thumbnail selection, framed images copied, manifest contains the
  feature.
- **Aggregation:** export two features into one explorer → manifest lists both;
  `rebuildManifest` yields both.
- **Smoke:** after export, `index.html` / `app.js` / `vendor/` exist.
- The JS renderer ships as a reviewed vendored asset; we exhaustively test the data
  contract rather than the browser rendering. Tests run on the iOS simulator like the
  rest of the suite.

## 13. Confirmed decisions

1. **Linear fallback** when a flow declares no transitions; explicit-only once any exist.
2. **Data emitted as JS globals** so the bundle opens via `file://` without a server.
3. **`exportFlowExplorer` is a separate method**, not folded into `generateDocumentation`.

## 14. New / changed files (anticipated)

- New: `Models/ScreenTransition.swift`, `Models/ExportedFeature.swift`,
  `Core/FlowExplorerExporter.swift`, `Core/SnapshotImageCopier.swift` (extracted),
  `Resources/FlowExplorerAssets/{index.html, app.js, vendor/*}`.
- Changed: `Models/DocumentedScreen.swift` (+`transitions`), `Core/DocumentedFlow.swift`
  (+`transitions:` on `addScreen`, +`exportFlowExplorer`), `Core/DoCCGenerator.swift`
  (use `SnapshotImageCopier`), `Package.swift` (target resources), docs.
