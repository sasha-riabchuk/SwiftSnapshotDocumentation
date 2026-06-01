import XCTest

/// Captures the **true composited framebuffer** of each glass screen via
/// `XCUIScreen.screenshot()` — pixel-exact to what the simulator renders (and device-accurate
/// if run on a device), unlike an in-process `drawHierarchy` capture which over-brightens glass.
/// Writes PNGs named `NN-<id>-iPhone15Pro-<theme>.png` so the Flow Explorer generator can read
/// them via `snapshotSourcePath`.
final class GlassUITests: XCTestCase {

    // Mirrors GlassCatalog.screens in the app target (UI tests can't import the app's types).
    private let screens = [
        "glass-buttons", "glass-card", "glass-controls", "glass-button-styles",
        "glass-alert", "glass-bottom-sheet", "glass-tab-bar",
    ]

    func testCaptureGlassFramebuffers() throws {
        let outDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("__Framebuffers__")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        for (index, id) in screens.enumerated() {
            for theme in ["light", "dark"] {
                let app = XCUIApplication()
                app.launchArguments = ["-glassScreen", id, "-appearance", theme]
                app.launch()
                // Let the compositor settle one real frame.
                _ = app.wait(for: .runningForeground, timeout: 5)
                Thread.sleep(forTimeInterval: 0.6)

                let shot = XCUIScreen.main.screenshot()
                let name = String(format: "%02d-%@-iPhone15Pro-%@.png", index + 1, id, theme)
                let url = outDir.appendingPathComponent(name)
                do {
                    try shot.pngRepresentation.write(to: url)
                    print("FRAMEBUFFER_WROTE=\(url.path)")
                } catch {
                    // Fallback: attach to the .xcresult if the repo path isn't writable.
                    let att = XCTAttachment(screenshot: shot)
                    att.name = name
                    att.lifetime = .keepAlways
                    add(att)
                    print("FRAMEBUFFER_ATTACHED=\(name) (write failed: \(error))")
                }
                app.terminate()
            }
        }
        print("FRAMEBUFFERS_DIR=\(outDir.path)")
    }
}
