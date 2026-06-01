# HostApp — pixel-exact Liquid Glass capture (UI-test framebuffer)

Liquid Glass (`.glassEffect()`) and blur materials are produced by the GPU **render server**.
No in-process snapshot reproduces them faithfully:

- `CALayer.render(in:)` (the library's default `.offscreen`) **skips backdrop filters** → glass
  renders transparent.
- `drawHierarchy(afterScreenUpdates:)` (the library's `.hostWindow`) *does* composite glass, but
  it **over-brightens** the material (~14% brighter than the screen) — measurably unfaithful.

The only faithful capture is the **actual composited framebuffer**, read with a UI test:
`XCUIScreen.screenshot()`. That's pixel-exact to what the simulator renders (and device-accurate
when run on a device). This directory does exactly that.

- `Sources/App/GlassProofApp.swift` — presents a glass screen chosen by the
  `-glassScreen <id>` / `-appearance light|dark` launch arguments (status bar hidden).
- `Sources/App/GlassScreens.swift` — the glass screens (`.glassEffect`, `.buttonStyle(.glass)`,
  glass alert / bottom sheet / tab bar) + the id→view router and the `GlassCatalog` order.
- `Sources/UITests/GlassUITests.swift` — launches the app once per screen × theme, captures
  `XCUIScreen.main.screenshot()`, and writes `Sources/UITests/__Framebuffers__/NN-<id>-iPhone15Pro-<theme>.png`.

## Run it

```sh
cd HostApp
ruby generate.rb            # (re)generate GlassProof.xcodeproj — only if you change targets/files
xcodebuild test -project GlassProof.xcodeproj -scheme GlassProofApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The committed framebuffer PNGs under `Sources/UITests/__Framebuffers__/` are the faithful
real-glass reference images. Re-running the UI test regenerates them.

`generate.rb` uses the Ruby `xcodeproj` gem (`gem install xcodeproj`). The generated
`GlassProof.xcodeproj` is committed and portable (relative paths).

## Notes

- The framebuffer is the **actual device size** of the simulator you run on (e.g. iPhone 17 Pro,
  1206×2622); the `iPhone15Pro` in the filename is just a stable label for the Flow Explorer.
- Status bar is hidden so the capture is pure screen content.
- Run on a **real device** for true device-accurate Liquid Glass — the simulator's glass is its
  own approximation of the device effect.
