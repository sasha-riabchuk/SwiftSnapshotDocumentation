# HostApp — capturing real backdrop effects (Liquid Glass / materials)

Backdrop effects — Liquid Glass (`.glassEffect()`), blur materials — are produced by the
**render server (compositor)** sampling the framebuffer behind the layer. swift-snapshot-testing's
default capture uses `CALayer.render(in:)`, which **skips backdrop filters by design**, so an
offscreen snapshot shows them transparent. The only path that composites them
(`drawHierarchy(afterScreenUpdates:)` in the key window) **requires a host application** — it
traps in a pure SwiftPM logic-test bundle (there is no key window).

This directory is that host application: a minimal iOS app + a **host-based** unit-test target,
so `DocumentedFlow`'s `captureMode: .hostWindow` runs where a real key window exists and captures
the **real** glass.

## Run it

```sh
cd HostApp
ruby generate.rb            # (re)generate GlassProof.xcodeproj — only needed if you change targets
xcodebuild test -project GlassProof.xcodeproj -scheme GlassProofApp \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

- **Verify (default):** compares against the committed baselines in
  `Sources/Tests/__Snapshots__/` — real frosted-glass capsules, light and dark.
- **Record:** set `RECORD_SNAPSHOTS` in the scheme/test-plan environment, then run.

`generate.rb` uses the Ruby `xcodeproj` gem (`gem install xcodeproj`). The generated
`GlassProof.xcodeproj` is committed and portable (relative paths, relative `..` package
reference), so you can open and run it directly without regenerating.

## How it works

- `Sources/App/GlassProofApp.swift` — a trivial SwiftUI app; its only job is to provide a real
  `UIApplication` + foreground `UIWindowScene` + key window.
- `Sources/Tests/GlassProofTests.swift` — runs `DocumentedFlow(configuration: .init(captureMode:
  .hostWindow))` on a Liquid Glass screen. Because the test is **hosted** by the app, the SDK's
  `drawHierarchy(afterScreenUpdates:)` path composites the glass instead of trapping.

## Generating a Flow Explorer that shows the real glass

`exportFlowExplorer` cannot be awaited from *inside* a host-app async XCTest (it throws an
XCTest `InvalidTransition`). So this target only **captures** the real-glass baselines
(`Sources/Tests/__Snapshots__/GlassProofTests/`). To build an interactive Flow Explorer whose
nodes show that real glass, generate it from a **stable SPM test** and point the exporter at
these baselines via `snapshotSourcePath`:

```swift
// In an SPM (logic-bundle) test — exportFlowExplorer is reliable there:
let flow = DocumentedFlow(name: "Real Glass", summary: "…")
await flow.addScreen(title: "Glass Buttons", view: { GlassButtonsScreen() },
                     devices: [.iPhone15Pro], themes: [.light, .dark])   // captured offscreen, just to register the screen
// …add the other screens…
try await flow.exportFlowExplorer(
    at: "FlowExplorer",
    snapshotSourcePath: "<repo>/HostApp/Sources/Tests/__Snapshots__/GlassProofTests"  // real-glass images
)
```

The offscreen captures only register the flow's screens; the exported node images are read
from the real-glass baselines, so the explorer shows the real frosted glass. The generated
bundle is written relative to the test process's working directory.

## In your own app

You don't need this directory — your app already has a host. In your app's **unit-test target
with a test host**, set `DocumentationConfiguration(captureMode: .hostWindow)` and the same real
capture applies. Without a host app, use `.offscreen` (the default) and substitute a stand-in for
glass/materials. See the top-level README's "effects that don't rasterize" section.
