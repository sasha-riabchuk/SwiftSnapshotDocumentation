# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this package does

A Swift library that combines PointFree's [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) with Apple's DocC. You write an XCTest that declares a user flow of SwiftUI screens; running the test captures device/theme snapshots and emits a `.docc` catalog (Markdown articles + copied images) you can open in Xcode's documentation viewer. It is meant to be consumed as a **test-target dependency** of an app, not run in production.

## Build & test commands

```sh
swift build                                    # build the library + examples
swift test                                     # run all tests
swift test --filter SwiftSnapshotDocumentationTests   # unit tests only
swift test --filter ExampleFlowDocumentationTests     # generates ExampleFlow.docc
swift test --filter ExampleFlowDocumentationTests/testGenerateExampleFlowDocumentation  # single test
```

**Critical: snapshot capture is iOS-only.** `captureSnapshot` in `DocumentedFlow.swift` is wrapped in `#if os(iOS)`; on macOS it just prints a warning and produces no images. To actually generate documentation with screenshots you must run the tests on an **iOS simulator**, e.g.:

```sh
xcodebuild test -scheme SwiftSnapshotDocumentation \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:ExampleFlowDocumentationTests
```

Note: `swift test` on the Mac does **not even build** — `ExampleFlowDocumentationTests` references iOS-only device constants (`.iPhone15Pro`, etc., gated behind `#if os(iOS)`) unconditionally, so the whole test build fails for macOS. Run the test suite via `xcodebuild test ... -destination 'platform=iOS Simulator,...'`. Boot a simulator first (`xcrun simctl boot <id>`) if `xcodebuild` reports "Invalid connectionUUID". The pure-logic unit tests live in `SwiftSnapshotDocumentationTests` and can be run in isolation with `-only-testing:SwiftSnapshotDocumentationTests`.

## Recording vs. verifying

The mode is an explicit, first-class `DocumentedFlow` concern via `record: SnapshotRecordMode?` — it is **not** the deprecated global `isRecording`. `captureSnapshot` wraps each `assertSnapshot` in `withSnapshotTesting(record:)` when a mode is set (`nil` honors the ambient config). Mapping in `SnapshotRecordMode.configuration`: `.record → .all`, `.recordMissing → .missing`, `.verify → .never`.

- `.verify` (CI/regression gate) — compares against committed snapshots; **fails on any drift**. The example defaults to this, so the documentation test now actually asserts.
- `.record` (run locally) — (re)writes snapshots; reports a failure per snapshot by design (swift-snapshot-testing always "fails" while recording). Commit snapshots + regenerated catalog together.

The example gates the mode on a `RECORD_SNAPSHOTS` env var. Note: a plain shell env var on the `xcodebuild` command line does **not** reach the simulator test process — set it in the scheme/test-plan environment. Snapshots land in `__Snapshots__/<TestFileBasename>/` next to the test file, filenames prefixed `<sanitizedTestName>.`.

## Architecture

The public API is a small builder + an internal generator, split into `Core/` and `Models/`:

- **`DocumentedFlow`** (`Core/`, `@MainActor`) — the entry point. `addScreen(...)` is the core method: it appends a `DocumentedScreen` and immediately loops every device×theme combination calling `captureSnapshot`. `generateDocumentation(...)` hands off to `DoCCGenerator`. Note `addScreen` captures snapshots eagerly as it's called, while doc generation happens later — so screen order in the file is the order in the docs. `captureSnapshot` hosts the view in a `UIHostingController` and snapshots the **controller** via `.image(on: device.viewImageConfig)` (not the bare view via `.image(layout:)`): on iOS 26 the view-only strategy renders `.frame(maxWidth/maxHeight: .infinity)` / safe-area-driven screens blank, while the hosted strategy mounts in a window so layout resolves (issue #2). When `configuration.captureSettleDuration > 0` it first mounts the same host in a live `UIWindow` and pumps the run loop for that duration so `onAppear`/`.task`/entrance animations settle before capture (SwiftUI `@State` persists across the strategy's re-mount); `0` (default) is a fully synchronous capture, byte-identical to the un-settled path. `captureSnapshot` branches on `configuration.captureMode`: `.offscreen` (default) is the `.image(on:)` layer render above (skips backdrop filters, so Liquid Glass/materials come out transparent); `.hostWindow` instead captures `host.view` via `.image(drawHierarchyInKeyWindow: true, …)` — a real render-server pass that *can* composite backdrop effects (materials, possibly Liquid Glass) but **traps without a host application**, so it's opt-in and only usable from an Xcode app test target (the SPM test bundle here can't exercise it). The library imports XCTest, so it must not be linked into production code — there is intentionally **no** public "is-capturing" environment flag for components to read (a 1.4.0 `\.isSnapshotCapture` was removed in 1.4.1 for exactly this reason); consumers substitute non-rasterizing effects in their own views (a real style, or their own SwiftUI env key set in the `view:` builder).

- **`DoCCGenerator`** (`Core/`, internal) — pure file-writing. Creates the `.docc` directory tree, **copies** images out of `__Snapshots__` into `Resources/Snapshots/` (stripping the `testName.` filename prefix, anchored on the `NN-` identifier), then writes the main catalog `.md` (with `@TechnologyRoot`/`@PageKind`) and one numbered article per screen (`01-<id>.md`, …) with light/dark side-by-side tables and prev/next/up navigation. The snapshot source dir is resolved deterministically from the test's `#file` (via `DocumentedFlow.snapshotDirectory(forFile:)`), not guessed from the working directory. Generation **throws** `DocumentationError` if no snapshots are found or none are copied, rather than silently emitting a catalog with broken image links — so the image copy happens before any Markdown is written. `generateDocumentation` returns a `GeneratedCatalog { path, screenCount, imageCount }` (`@discardableResult`) so callers can verify success without scraping stdout. On a non-iOS platform a "no snapshots" failure is remapped (via the testable `DocumentedFlow.mappedGenerationError`) to `DocumentationError.captureUnavailable` — but generation still succeeds on macOS when committed baselines exist (capture is iOS-only; generation isn't).

- **Models** — value types describing the inputs:
  - `DocumentedScreen` — a `Sendable` **metadata** record (title/description/discussion/devices/themes/callouts). It deliberately does **not** hold the SwiftUI view: the `() -> any View` builder is passed to `addScreen`, used immediately by `captureSnapshot`, and never retained on the long-lived screen. `id` is derived from the title via `sanitizedForFilename()` (lowercased, hyphenated) unless given. Defines the nested `Callout` (`.note/.important/.warning/.tip/.experiment`).
  - `DeviceConfiguration` — wraps a swift-snapshot-testing `ViewImageConfig`. Predefined devices + `allIPhones`/`allIPads`/`allDevices`. **iOS-only static members** (also under `#if os(iOS)`); equality/hashing key on `name`.
  - `ThemeConfiguration` — `.light`/`.dark`/`allThemes`, maps to a SwiftUI `ColorScheme`.
  - `DocumentationConfiguration` — capture + generation options. Supplied at `DocumentedFlow.init` (not just at `generateDocumentation`) because the comparison **tolerances are consumed at capture time**: `snapshotPrecision`/`snapshotPerceptualPrecision` map `overallTolerance`/`perPixelTolerance` (as `1 - tolerance`, clamped) onto swift-snapshot-testing's `.image(precision:perceptualPrecision:)`. `deviceFrames` (default on) and `organizeByDevice` are applied during the generator's **copy** step (see below). `createIndexPage` (default on) toggles the root page's curated `Topics → Screens` listing, and `includeFlowDiagram` adds a Mermaid flowchart of the screen sequence after the overview — both in `generateCatalogFile`. `captureSettleDuration` (default `0`, a `TimeInterval`) is consumed in `captureSnapshot`: `> 0` enables the live-window settle path for entrance-animated screens (see `DocumentedFlow` above). All `DocumentationConfiguration` flags are now wired.
  - `DeviceFrame` + `DeviceFrameRenderer` — when `deviceFrames` is on, each copied image is composited into a procedurally-drawn bezel (rounded body, inset rounded-corner screen, optional Dynamic Island) via CoreGraphics/ImageIO (cross-platform, so testable on macOS). Geometry per device lives in `DeviceConfiguration.frame` (`.phone`/`.pad`). The renderer flips the context to a top-left origin for path math but must flip **locally** around the screen rect when drawing the screenshot (`CGContext.draw` would otherwise render a normal PNG upside down) — and the notch is positioned from the high-y edge for the same reason. The regression snapshots in `__Snapshots__` stay bare; only catalog copies are framed.
  - `organizeByDevice` groups copied images into `Resources/Snapshots/<deviceName>/` subfolders. The Markdown image links are **not** changed — DocC resolves resources by filename regardless of folder, so both flags only touch the copy step, never the article generation.
  - `ScreenTransition` — a `Sendable` value (`target: String`, `label: String?`) that declares a directed edge from one screen to another. `DocumentedScreen` gains a `transitions: [ScreenTransition]` property (default `[]`). Created via `ScreenTransition.to(_ target:on:)`.
  - `FlowEdgeResolver` — resolves `ScreenTransition` targets to concrete `DocumentedScreen` indices. Rule: if **no** screen declares any transitions, edges follow `addScreen` order (linear fallback); if **any** screen declares transitions, only explicit edges are used. Targets are matched by `screen.id` first, then by `screen.sanitizedForFilename(title)`. Unresolved targets are collected into `ExportedFeature.unresolvedTransitions` and skipped; the rest of the graph is still exported.

- **Flow Explorer** (`Core/`):
  - `FlowExplorerExporter` (internal) — writes the static web bundle. Reuses `SnapshotImageCopier` (see below) to resolve, copy, and frame thumbnails; runs `FlowEdgeResolver` to build the edge list; serialises everything as `FlowData`. Per feature it writes: `<Feature>/feature.json` (pure JSON marker used by the manifest scanner), `<Feature>/flows.js` (assigns `window.FLOW_DATA["<name>"] = {…feature JSON…}`), and `<Feature>/images/` (framed snapshots). The top-level `manifest.js` assigns `window.FLOW_MANIFEST = { features: [{name, dir}] }` and is rebuilt by scanning `*/feature.json`. Data is emitted as JS globals (`window.*` assignments) specifically so `index.html` works over `file://` with no server. Each **variant** carries an embedded downscaled `data:` URI thumbnail (via `FlowExplorerExporter.thumbnailDataURI`, an orientation-preserving ImageIO thumbnail) so the toolbar can re-skin nodes (toggle device family / theme) and they render in the `<canvas>` even over `file://` (browsers refuse to draw `file://` images into a canvas). The variant-panel images stay as file refs (DOM `<img>` loads those fine). `app.js` builds the toolbar from the device families/themes present, defaults to the first of each, and falls back to a screen's closest variant when it lacks the exact selection. The web shell (`index.html`, `app.js`, `vendor/` containing cytoscape.min.js, dagre.min.js, cytoscape-dagre.js) is **vendored as SwiftPM package resources** and copied from `Bundle.module` (the `FlowExplorerAssets` bundle resource) into the explorer directory; it is refreshed automatically when the bundled copy's modification date is newer than the deployed copy (e.g. after a library upgrade).
  - `exportFlowExplorer(at:snapshotSourcePath:configuration:) async throws -> ExportedFeature` — public entry point on `DocumentedFlow`; delegates to `FlowExplorerExporter`. Returns `ExportedFeature { featurePath, screenCount, edgeCount, imageCount, unresolvedTransitions }` (`@discardableResult`).
  - `FlowExplorer.rebuildManifest(at:)` — static helper that rescans `<dir>/*/feature.json` and rewrites `<dir>/manifest.js`. Each `exportFlowExplorer` call also rescans (so the manifest is always at least as fresh as the last export); `rebuildManifest` is provided for the multi-feature case to guarantee a complete index after all tests have run.

- **`SnapshotImageCopier`** (internal, `Core/`) — shared helper for resolving a snapshot from `__Snapshots__`, applying the device frame (when `deviceFrames` is on), and writing it to a destination path. Introduced so that both `DoCCGenerator` and `FlowExplorerExporter` use identical resolve/copy/frame logic rather than duplicating it.

- **`FlowData` JS-globals contract** — the JS payload written by `FlowExplorerExporter` uses `window.*` assignments (`window.FLOW_DATA["<name>"] = {…}` in each feature's `flows.js`; `window.FLOW_MANIFEST = { features: [{name, dir}] }` in the top-level `manifest.js`) rather than `fetch`/`import`, which is what makes the explorer functional over `file://`. The schema is considered internal and may change between releases; the web shell is always written alongside the data files.

- **Derived `manifest.js` aggregation** — each `exportFlowExplorer` call writes `<featureName>/feature.json` then rescans the parent directory for all `*/feature.json` files to regenerate `manifest.js`. This means a partial manifest is always available after any single export. `FlowExplorer.rebuildManifest(at:)` performs only the rescan step (no export) and is the recommended call after a full test suite to guarantee the index reflects every feature.

The **snapshot filename contract** is the coupling point between the two halves: `DocumentedFlow.captureSnapshot` formats names as `%02d-<screen.id>-<device.name>-<theme.name>`, and `DoCCGenerator.snapshotFilename` must produce the identical string (plus extension) for the Markdown image links to resolve. Changing the naming in one place requires changing the other.

## Targets

- `SwiftSnapshotDocumentation` — the library (the only published product).
- `SwiftSnapshotDocumentationExamples` — sample SwiftUI views (`WelcomeExampleView`, `LoginExampleView`, `ProfileFormExampleView`) used by the example test.
- `SwiftSnapshotDocumentationTests` — unit tests for the library.
- `ExampleFlowDocumentationTests` — end-to-end test that actually generates a DocC catalog; the canonical usage example.

`HostApp/` is a separate, generated Xcode project (not part of the SPM package) that captures **pixel-exact** Liquid Glass. Fidelity ladder we established: `.offscreen` (`CALayer.render`) renders glass transparent; `.hostWindow` (`drawHierarchy` in the key window) composites glass but **over-brightens it ~14%** (measured vs the simulator framebuffer); the only faithful capture is the **actual framebuffer via a UI test** (`XCUIScreen.screenshot()`). So HostApp is now a minimal app that presents a glass screen by `-glassScreen`/`-appearance` launch args + a **UI-test target** that writes framebuffer PNGs to `Sources/UITests/__Framebuffers__/`. `generate.rb` (Ruby `xcodeproj` gem) regenerates `GlassProof.xcodeproj`. The Flow Explorer for the glass showcase is generated by a throwaway SPM test that reads those framebuffer PNGs via `exportFlowExplorer(snapshotSourcePath:)`. For device-accurate glass, run the UI test on a real device.

## Platform requirements

iOS 17+ / macOS 14+, Swift 5.9+ (tools-version 5.9). Public symbols that depend on UIKit/snapshot config are gated behind `#if os(iOS)` / `@available(iOS 17.0, *)` — preserve this gating when adding device-related API so the package keeps building on macOS.
