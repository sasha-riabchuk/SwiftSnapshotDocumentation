import XCTest
import SwiftUI
import SwiftSnapshotDocumentation

// MARK: - Inline Liquid Glass screens (depend only on the published library product)

private struct GlassBackdrop: View {
    var body: some View {
        LinearGradient(colors: [.blue, .purple, .pink, .orange],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

@ViewBuilder
private func glassCapsule(_ label: some View) -> some View {
    let padded = label.foregroundStyle(.white).padding(.horizontal, 40).padding(.vertical, 18)
    if #available(iOS 26.0, *) {
        padded.glassEffect(.regular, in: .capsule)
    } else {
        padded.background(.ultraThinMaterial, in: Capsule())
    }
}

/// Glass buttons over a gradient.
private struct GlassButtonsScreen: View {
    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 24) {
                Text("Liquid Glass").font(.largeTitle.bold()).foregroundStyle(.white)
                glassCapsule(Text("Continue").fontWeight(.semibold))
                glassCapsule(Text("Maybe Later"))
            }
        }
    }
}

/// A glass card panel.
private struct GlassCardScreen: View {
    var body: some View {
        ZStack {
            GlassBackdrop()
            let card = VStack(alignment: .leading, spacing: 10) {
                Text("Now Playing").font(.title2.bold()).foregroundStyle(.white)
                Text("Liquid Glass adapts to the content behind it, refracting the gradient.")
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(28)
            .frame(width: 320, alignment: .leading)
            if #available(iOS 26.0, *) {
                card.glassEffect(.regular, in: .rect(cornerRadius: 28))
            } else {
                card.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            }
        }
    }
}

/// A glass control bar (toolbar of SF Symbols).
private struct GlassControlsScreen: View {
    private let icons = ["backward.fill", "play.fill", "forward.fill", "shuffle", "repeat"]
    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack {
                Spacer()
                let bar = HStack(spacing: 28) {
                    ForEach(icons, id: \.self) { name in
                        Image(systemName: name).font(.title2).foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 28).padding(.vertical, 18)
                if #available(iOS 26.0, *) {
                    bar.glassEffect(.regular, in: .capsule)
                } else {
                    bar.background(.ultraThinMaterial, in: Capsule())
                }
                Spacer().frame(height: 60)
            }
        }
    }
}

/// Builds a "Real Glass" flow captured via `.hostWindow` (real frosted glass) and exports a
/// Flow Explorer so the real effect shows up in the interactive viewer. Run inside the host app.
final class GlassProofTests: XCTestCase {
    @MainActor
    func testRealGlassViaHostWindowMode() async throws {
        let isRecording = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil
        let flow = DocumentedFlow(
            name: "Real Glass",
            summary: "Liquid Glass captured via .hostWindow in a host app",
            overview: "Real iOS 26 Liquid Glass, composited through the render server in a host application — the effect users actually see, not the transparent offscreen result.",
            configuration: .init(captureMode: .hostWindow),
            record: isRecording ? .record : .verify
        )

        await flow.addScreen(
            title: "Glass Buttons",
            description: "Real .glassEffect() capsule buttons over a gradient",
            view: { GlassButtonsScreen() },
            devices: [.iPhone15Pro], themes: [.light, .dark],
            transitions: [.to("Glass Card")]
        )
        await flow.addScreen(
            title: "Glass Card",
            description: "A Liquid Glass card refracting the backdrop",
            view: { GlassCardScreen() },
            devices: [.iPhone15Pro], themes: [.light, .dark],
            transitions: [.to("Glass Controls")]
        )
        await flow.addScreen(
            title: "Glass Controls",
            description: "A Liquid Glass control bar of SF Symbols",
            view: { GlassControlsScreen() },
            devices: [.iPhone15Pro], themes: [.light, .dark]
        )

        // NOTE: capture only. exportFlowExplorer is intentionally NOT called here — awaiting
        // it inside a host-app async XCTest throws an XCTest `InvalidTransition`. The Flow
        // Explorer is generated from these real-glass baselines by the stable SPM test
        // `ExampleFlowDocumentationTests.testGenerateRealGlassExplorer`.
        print("REAL_GLASS_CAPTURED")
    }
}
