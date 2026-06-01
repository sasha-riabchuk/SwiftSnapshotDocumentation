import XCTest
import SwiftUI
import SwiftSnapshotDocumentation

/// A Liquid Glass screen (inlined so the test depends only on the published library product).
private struct GlassScreen: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue, .purple, .pink, .orange],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Liquid Glass").font(.largeTitle.bold()).foregroundStyle(.white)
                glass(Text("Continue").fontWeight(.semibold))
                glass(Text("Maybe Later"))
            }
        }
    }
    @ViewBuilder private func glass(_ label: some View) -> some View {
        let padded = label.foregroundStyle(.white).padding(.horizontal, 40).padding(.vertical, 18)
        if #available(iOS 26.0, *) {
            padded.glassEffect(.regular, in: .capsule)
        } else {
            padded.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

/// Drives the package's own `captureMode: .hostWindow` from inside a host application,
/// where a real key window exists — confirming the library captures real Liquid Glass
/// (not the transparent offscreen result). Records snapshots next to this file.
final class GlassProofTests: XCTestCase {
    @MainActor
    func testRealGlassViaHostWindowMode() async throws {
        let isRecording = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil
        let flow = DocumentedFlow(
            name: "Real Glass",
            summary: "Liquid Glass captured via .hostWindow in a host app",
            configuration: .init(deviceFrames: false, captureMode: .hostWindow),
            record: isRecording ? .record : .verify
        )
        await flow.addScreen(
            title: "Liquid Glass Real",
            description: "Real .glassEffect() captured through the compositor",
            view: { GlassScreen() },
            devices: [.iPhone15Pro],
            themes: [.light, .dark]
        )
        print("REAL_GLASS_DONE")
    }
}
