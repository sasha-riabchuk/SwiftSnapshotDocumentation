import SwiftUI

/// Minimal host application. Its only purpose is to provide a real UIApplication +
/// foreground UIWindowScene + key window, so a host-based unit test can capture
/// compositor-backed effects (Liquid Glass / materials) via `drawHierarchy(afterScreenUpdates:)`.
@main
struct GlassProofApp: App {
    var body: some Scene {
        WindowGroup {
            Color.black.ignoresSafeArea()
        }
    }
}
