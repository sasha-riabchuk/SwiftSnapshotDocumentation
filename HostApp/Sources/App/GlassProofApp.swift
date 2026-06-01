import SwiftUI

/// Host app for framebuffer capture. The UI test launches it with `-glassScreen <id>` and
/// `-appearance light|dark`; the app presents that glass screen full-screen so the UI test
/// can grab the true composited framebuffer via `XCUIScreen.screenshot()` — pixel-exact to
/// what the simulator (or a device) actually renders, unlike an in-process `drawHierarchy`.
@main
struct GlassProofApp: App {
    private var screenID: String { Self.arg("-glassScreen") ?? "" }
    private var appearance: ColorScheme { Self.arg("-appearance") == "dark" ? .dark : .light }

    var body: some Scene {
        WindowGroup {
            GlassRouter(id: screenID)
                .preferredColorScheme(appearance)
                .statusBarHidden(true)
        }
    }

    private static func arg(_ key: String) -> String? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: key), i + 1 < a.count else { return nil }
        return a[i + 1]
    }
}
