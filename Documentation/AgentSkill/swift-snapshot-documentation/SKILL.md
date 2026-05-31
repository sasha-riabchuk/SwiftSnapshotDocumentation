---
name: swift-snapshot-documentation
description: Use when adding or maintaining visual DocC documentation for SwiftUI screens with the SwiftSnapshotDocumentation library — creating a DocumentedFlow, generating snapshot-based docs, recording vs verifying baselines, or wiring it into a test target. Triggers include "document this screen/flow", "add snapshot docs", "visual regression docs", "DocumentedFlow".
---

# SwiftSnapshotDocumentation

Generate DocC documentation from SwiftUI screens, with snapshot images captured
across devices and themes. One test both documents the UI and guards it against
regressions.

## Before you start — verify the setup

1. The library belongs to a **test target**, not the app target. If it isn't a
   dependency yet, add it to the test target:
   ```swift
   .package(url: "https://github.com/sasha-riabchuk/SwiftSnapshotDocumentation", from: "1.0.0")
   // ...then in the testTarget dependencies:
   .product(name: "SwiftSnapshotDocumentation", package: "SwiftSnapshotDocumentation")
   ```
2. Snapshot capture is **iOS-only**. Plan to run tests on an iOS simulator, never a
   plain `swift test` on macOS.

## Authoring a documentation test

Build a `DocumentedFlow`, add each screen, then generate the catalog:

```swift
import XCTest
import SwiftSnapshotDocumentation
@testable import MyApp

@MainActor
final class FeatureDocsTests: XCTestCase {
    func testFeatureDocs() async throws {
        let recording = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil
        let flow = DocumentedFlow(
            name: "Feature",
            summary: "One-line summary",
            overview: "Markdown overview of the flow.",
            record: recording ? .record : .verify
        )

        await flow.addScreen(
            title: "Screen Title",
            description: "Short description",
            discussion: "Optional longer Markdown discussion.",
            view: { MyView() },                 // any SwiftUI view
            devices: [.iPhone15Pro, .iPadPro129],
            themes: [.light, .dark],
            callouts: [.init(type: .note, content: "Something worth highlighting")]
        )
        // ...repeat addScreen for each screen/state...

        try await flow.generateDocumentation(outputPath: "Feature.docc")
    }
}
```

Document multiple **states** of one screen by calling `addScreen` again with a
different `view:` and a distinct `title:` (e.g. "Profile — Empty", "Profile — Filled").

## Choices to make

- **Devices**: `.iPhoneSE`, `.iPhone15Pro`, `.iPhone15ProMax`, `.iPadPro11`,
  `.iPadPro129`, or `.allIPhones` / `.allIPads` / `.allDevices`.
- **Themes**: `.light`, `.dark`, `.allThemes`.
- **Record mode** (`record:`): `.verify` for CI (fails on UI drift), `.record` to
  (re)generate baselines, `.recordMissing` to add new screens without touching
  existing ones. Omit to honor the ambient snapshot-testing config.
- **`DocumentationConfiguration`** (pass to `DocumentedFlow(configuration:)`):
  `deviceFrames` (default on — composites a device bezel), `organizeByDevice`,
  `includeFlowDiagram`, `createIndexPage`, image format, and comparison tolerances
  (`perPixelTolerance`/`overallTolerance`, applied at capture time).

## Running

```sh
xcodebuild test \
  -scheme <AppScheme> \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:<TestTarget>/<TestClass>
```

- **First time / UI changed:** set `RECORD_SNAPSHOTS` in the scheme or test-plan
  environment (a plain shell var on the `xcodebuild` line does NOT reach the
  simulator). Recording reports a failure per snapshot **by design** — that's
  expected; review and commit the generated `__Snapshots__` PNGs and the `.docc`.
- **Afterwards / CI:** run without it. `.verify` mode passes if the UI matches and
  fails on drift.

## Verifying success

- `generateDocumentation` returns `GeneratedCatalog { path, screenCount, imageCount }`.
  Check `imageCount > 0` to confirm it actually produced images — don't rely on stdout.
- If it throws `DocumentationError`, read the message — it names the fix. Off-iOS with
  no committed snapshots you get `.captureUnavailable` (run on a simulator); a missing
  baseline gives `.snapshotsNotFound` / `.noSnapshotsCopied` (record first).
- Confirm `<output>.docc/Resources/Snapshots/` contains the images and that
  `<output>.docc/<Name>.md` plus per-screen `NN-*.md` articles exist.

## Flow Explorer

Export an interactive graph of the screen flow (framed thumbnail nodes + directed edges)
alongside your DocC catalog:

```swift
// Declare transitions on each screen to express branches:
await flow.addScreen(
    title: "Welcome",
    description: "Landing screen",
    view: { WelcomeView() },
    devices: [.iPhone15Pro],
    themes: [.light, .dark],
    transitions: [
        .to("Login"),
        .to("Guest Browse", on: "continue as guest")
    ]
)

// Write the web bundle:
try await flow.exportFlowExplorer(at: "FlowExplorer")
```

Open `FlowExplorer/index.html` in a browser — data is emitted as JS globals (with
embedded thumbnails) so `file://` works with no server required. The viewer is a
Figma-style canvas: pan/zoom, click a node for the inspector (all device × theme
variants), and a toolbar to toggle the whole flow between **iPhone/iPad** and
**Light/Dark** (toggles show only for the device families / themes you captured).

If no screen declares `transitions:`, edges follow `addScreen` order (linear). Targets that
cannot be resolved by title or id are skipped and reported in `ExportedFeature.unresolvedTransitions`.
When any screen declares `transitions:`, the linear fallback is disabled flow-wide, so screens
without an incoming or outgoing transition appear as unconnected nodes — give every screen a
transition for a fully connected graph.

For multiple features, export each into the same directory, then call
`FlowExplorer.rebuildManifest(at: "FlowExplorer")` once to finalize the shared index.

## Pitfalls

- Adding the package to the app target instead of the test target.
- Running `swift test` on macOS (won't build/capture) instead of `xcodebuild` on a sim.
- Calling `generateDocumentation` without `addScreen` having captured in the same test.
- Expecting `.verify` to pass before any baseline has been recorded and committed.
- Snapshot baselines are environment-specific (Xcode/simulator/OS); diffs across
  machines are expected — pin the toolchain or re-record.
