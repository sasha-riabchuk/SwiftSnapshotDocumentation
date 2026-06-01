# AGENTS.md

Guidance for AI coding agents integrating **SwiftSnapshotDocumentation** into a project.
(Human contributors: see `CLAUDE.md` for working *on* this library.)

## What this library is

A **test-target** dependency that turns SwiftUI screens into DocC documentation.
You write an XCTest that declares a flow of screens; running it captures
snapshots (via PointFree's swift-snapshot-testing) and emits a `.docc` catalog
**and/or** an interactive, browser-based **Flow Explorer** (a Figma-style graph of
your screens). One test both **documents** your UI and **guards** it against
regressions.

## Mental model (4 lines)

1. A `DocumentedFlow` is an ordered list of screens you build with `addScreen`.
2. `addScreen` captures a snapshot for every `device × theme` immediately.
3. `generateDocumentation` writes a DocC catalog from those snapshots.
4. `exportFlowExplorer` writes an interactive web graph from those same snapshots
   (declare `transitions:` on screens to make it a branching diagram).

## Integration checklist

1. Add the package **to the test target only** (it imports XCTest and snapshot-testing):
   ```swift
   .testTarget(
       name: "MyAppTests",
       dependencies: [
           .product(name: "SwiftSnapshotDocumentation", package: "SwiftSnapshotDocumentation")
       ]
   )
   ```
   In `dependencies:` of the `Package`:
   ```swift
   .package(url: "https://github.com/sasha-riabchuk/SwiftSnapshotDocumentation", from: "1.0.0")
   ```
2. Write a documentation test (canonical pattern below).
3. **Run on an iOS simulator** — snapshot capture is iOS-only. A plain `swift test`
   on macOS will not capture anything.
4. **Record once, then verify.** First run records baselines; commit them. Later runs
   verify and fail on UI drift.

## Canonical example (compiles as-is)

```swift
import XCTest
import SwiftSnapshotDocumentation
@testable import MyApp

@MainActor
final class OnboardingDocsTests: XCTestCase {
    func testOnboardingDocs() async throws {
        // Verify by default (regression gate); record when RECORD_SNAPSHOTS is set
        // in the scheme/test-plan environment.
        let recording = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil

        let flow = DocumentedFlow(
            name: "Onboarding",
            summary: "New user onboarding",
            overview: "Welcome → Login → Profile.",
            record: recording ? .record : .verify
        )

        await flow.addScreen(
            title: "Welcome",
            description: "Landing screen",
            view: { WelcomeView() },
            devices: [.iPhone15Pro, .iPadPro129],
            themes: [.light, .dark],
            callouts: [.init(type: .tip, content: "Gradient adapts to color scheme")]
        )

        await flow.addScreen(
            title: "Login",
            description: "Authentication",
            view: { LoginView() },
            devices: [.iPhone15Pro],
            themes: [.light, .dark]
        )

        try await flow.generateDocumentation(outputPath: "Onboarding.docc")
    }
}
```

Run it (replace the scheme/destination):
```sh
xcodebuild test \
  -scheme MyAppScheme \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MyAppTests/OnboardingDocsTests
```

## API quick reference

- **`DocumentedFlow(name:summary:overview:configuration:record:)`** — `overview` and
  `configuration` (see below) and `record` are optional.
- **`addScreen(title:description:discussion:view:devices:themes:callouts:)` `async`** —
  `view:` is `() -> some View`; `discussion`/`callouts` optional.
- **`generateDocumentation(outputPath:snapshotSourcePath:configuration:)` `async throws`** —
  writes the `.docc` and **returns** `GeneratedCatalog { path, screenCount, imageCount }`
  (`@discardableResult` — safe to ignore, or assert `imageCount > 0` to verify success).
  Throws `DocumentationError`; off-iOS with no pre-recorded snapshots it throws
  `.captureUnavailable` (message points you to run on a simulator).
- **Devices** (iOS-only): `.iPhoneSE`, `.iPhone15Pro`, `.iPhone15ProMax`, `.iPadPro11`,
  `.iPadPro129`, and `.allIPhones` / `.allIPads` / `.allDevices`.
- **Themes**: `.light`, `.dark`, `.allThemes`.
- **`SnapshotRecordMode`**: `.verify` (CI gate), `.record` (regenerate baselines),
  `.recordMissing` (record only new screens).
- **`Callout`**: `type` is `.note` / `.important` / `.warning` / `.tip` / `.experiment`.
- **`DocumentationConfiguration(imageFormat:deviceFrames:perPixelTolerance:overallTolerance:createIndexPage:includeFlowDiagram:organizeByDevice:captureSettleDuration:)`**
  — pass it to `DocumentedFlow(configuration:)`. Tolerances are applied at capture time.
  `deviceFrames` (default `true`) composites a device bezel onto catalog images.
  `captureSettleDuration` (default `0`) — seconds to let entrance animations / `onAppear` /
  `.task` settle in a live window before capture; set `0.6`–`1.0` for screens that animate in,
  leave `0` otherwise (synchronous capture, existing baselines unaffected).
  `captureMode` (default `.offscreen`) — `.offscreen` renders the layer tree (device-accurate,
  works headless, but **doesn't composite** Liquid Glass / materials); `.hostWindow` captures
  through the render server so backdrop effects **can** composite, but **requires a host-app
  test target** (it traps in a pure SwiftPM logic-test bundle) and takes safe-area/scale from
  the host window. `.hostWindow` composites glass/materials but **over-brightens glass ~14%**
  (measured); for **pixel-exact** glass, capture the framebuffer via a UI test
  (`XCUIScreen.screenshot()`) — see the repo's `HostApp/`. In `.offscreen` (no host app),
  backdrop effects render transparent; there is no faithful offscreen capture of them.
- **`addScreen(... transitions: [ScreenTransition] = [])`** — declare directed edges from
  this screen to others; edges are optional and default to none (linear order is used
  when no screen declares any transitions).
- **`ScreenTransition.to(_ target: String, on: String? = nil)`** — a transition to another
  screen identified by title or id, with an optional edge label (e.g. `"continue as guest"`).
- **`exportFlowExplorer(at:snapshotSourcePath:configuration:) async throws -> ExportedFeature`**
  — writes a static, interactive Flow Explorer web bundle (Cytoscape.js + dagre) to the
  given directory. Open `index.html` in any browser; `file://` works — no server needed.
- **`FlowExplorer.rebuildManifest(at:)`** — rescans a directory for all exported features
  and rewrites the shared manifest. Call once after all features have been exported to
  guarantee the multi-feature index is complete.

## Common mistakes (and the fix)

| Symptom | Cause | Fix |
|---|---|---|
| Build error: `has no member 'iPhone15Pro'` on macOS | Capture is iOS-only | Run the test on an iOS **simulator**, not `swift test` on macOS |
| `DocumentationError.noSnapshotsCopied` / `snapshotsNotFound` | No snapshots on disk | Ensure `addScreen` ran in the **same test** before `generateDocumentation`; record first |
| Test fails with "Record mode is on…" | `record: .record` is set | Expected while recording — review and commit the new snapshots, then switch back to `.verify` |
| Verify fails with no reference snapshot | Baselines not committed | Record once (`RECORD_SNAPSHOTS=1`), commit the `__Snapshots__` PNGs |
| Package won't build in the app target | Added to the wrong target | Add it to the **test** target only |
| Docs have broken image links | Capture didn't run (e.g. macOS) | Capture on iOS; generation **throws** if zero images — read the error, it names the fix |
| Flow Explorer page is blank / `flows.js` fails to load over `file://` | Expecting a server | Data is emitted as JS globals, so double-clicking `index.html` works; any static server is also fine |
| A screen presenting `.alert` / `.sheet` / `.fullScreenCover` / `.popover` / `.confirmationDialog` / `Menu` snapshots as the empty screen behind it | Native presentations live in a **separate UIKit window** the view-snapshot can't see | Render the **presented appearance inline** (a dimmed `ZStack` with the alert card / sheet / popover drawn in the view tree). `TabView` / `NavigationStack` *are* in the tree and snapshot fine. |
| A card/overlay built with `.regularMaterial` / `.ultraThinMaterial` is **transparent** in the snapshot (content bleeds through) | Blur **materials don't render** in offscreen snapshots | Use a solid color instead, e.g. `Color(.tertiarySystemBackground)` (white in light, `#2C2C2E` in dark) — renders correctly and still reads as a native elevated card |
| A screen that **animates in** (`onAppear { withAnimation { … } }` from `opacity 0` / offset / scale) snapshots **blank/white** | A snapshot is one synchronous frame, captured at the *start* of the entrance animation (content still hidden) | Set `DocumentationConfiguration(captureSettleDuration: 0.6...1.0)` — hosts the view in a live window and pumps the run loop so the animation settles before capture. Default `0` is synchronous (existing baselines unaffected); re-record after enabling |
| A `VideoPlayer` / `AVPlayerLayer` / `Map` / Metal screen is **blank** | Compositor-backed layers don't rasterize in offscreen snapshots; `captureSettleDuration` won't help | Capture from a **host-app** test target with `captureMode: .hostWindow` (real render-server pass); offscreen can't composite them |
| A **Liquid Glass** (`.glassEffect()`) button/screen is transparent or blank | Glass samples the backdrop; the default offscreen render skips backdrop filters | `.hostWindow` composites glass but **over-brightens ~14%**; for **pixel-exact** glass capture the framebuffer via a UI test (`XCUIScreen.screenshot()`) — see the repo's `HostApp/` |
| Adding a new screen makes the whole `.verify` test fail / re-records every snapshot | `.record` overwrites everything; `.verify` fails on the missing one | Use `record: .recordMissing` (records only the new screens, verifies the rest), then commit the new `__Snapshots__` PNGs |
| New `addScreen` is an orphan node in the explorer | Once *any* screen declares `transitions:`, linear fallback is off flow-wide | Give the new screen (and/or its neighbors) a `transitions:` edge, or leave it intentionally disconnected |
| Flow Explorer nodes look blurry / squished for iPad | (fixed in 1.2.0) | Update to ≥1.2.0 — nodes size to the real aspect ratio and thumbnails are high-res JPEG |

## Notes for agents

- Errors are self-describing: `DocumentationError.description` tells you the corrective
  action. Surface it; don't swallow it.
- Snapshot baselines are tied to the Xcode/simulator they were recorded on; a different
  toolchain may produce diffs in `.verify` mode.
- A reusable Claude Code **skill** is shipped at
  `Documentation/AgentSkill/swift-snapshot-documentation/` — copy that folder into your
  project's `.claude/skills/` to give your agent on-demand, invokable guidance.
