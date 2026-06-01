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

// MARK: - iOS 26 glass component helpers

/// Wraps content in real Liquid Glass (`.glassEffect`, iOS 26), with a material fallback.
@ViewBuilder
private func glassed(_ content: some View, in shape: some Shape) -> some View {
    if #available(iOS 26.0, *) { content.glassEffect(.regular, in: shape) }
    else { content.background(.ultraThinMaterial, in: shape) }
}

/// A button using the real iOS 26 `.buttonStyle(.glass)` / `.glassProminent`, with a fallback.
@ViewBuilder
private func glassButton(_ title: String, role: ButtonRole? = nil, prominent: Bool = false) -> some View {
    let b = Button(title, role: role) {}.controlSize(.large)
    if #available(iOS 26.0, *) {
        if prominent { b.buttonStyle(.glassProminent) } else { b.buttonStyle(.glass) }
    } else {
        if prominent { b.buttonStyle(.borderedProminent) } else { b.buttonStyle(.bordered) }
    }
}

/// `.buttonStyle(.glass)` / `.glassProminent` (iOS 26).
private struct GlassButtonStylesScreen: View {
    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 22) {
                Text(".buttonStyle(.glass)").font(.title2.bold()).foregroundStyle(.white)
                glassButton("Glass")
                glassButton("Glass Prominent", prominent: true)
                glassButton("Delete", role: .destructive, prominent: true)
            }
            .tint(.white)
            .padding(40)
        }
    }
}

/// An alert rendered inline with a real glass card + glass buttons (iOS 26).
private struct GlassAlertScreen: View {
    var body: some View {
        ZStack {
            GlassBackdrop()
            Color.black.opacity(0.18).ignoresSafeArea()
            let alert = VStack(spacing: 18) {
                Image(systemName: "trash").font(.largeTitle).foregroundStyle(.white)
                VStack(spacing: 6) {
                    Text("Delete Project?").font(.headline).foregroundStyle(.white)
                    Text("This action can’t be undone.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
                }
                HStack(spacing: 12) {
                    glassButton("Cancel")
                    glassButton("Delete", role: .destructive, prominent: true)
                }
                .tint(.white)
            }
            .padding(28).frame(width: 304)
            glassed(alert, in: RoundedRectangle(cornerRadius: 28))
        }
    }
}

/// A bottom sheet rendered inline with a real glass panel (iOS 26).
private struct GlassBottomSheetScreen: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            GlassBackdrop()
            Color.black.opacity(0.12).ignoresSafeArea()
            let sheet = VStack(spacing: 18) {
                Capsule().fill(.white.opacity(0.6)).frame(width: 40, height: 5)
                Text("Share Photo").font(.title3.bold())
                    .foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 16) {
                    shareIcon("airplane", "AirDrop"); shareIcon("message.fill", "Messages")
                    shareIcon("link", "Copy"); shareIcon("square.and.arrow.up", "More")
                }
                glassButton("Done", prominent: true).tint(.white).frame(maxWidth: .infinity)
            }
            .padding(24).padding(.bottom, 12).frame(maxWidth: .infinity)
            glassed(sheet, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .ignoresSafeArea(edges: .bottom)
        }
    }
    private func shareIcon(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.white).frame(width: 56, height: 56)
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
    }
}

/// A floating glass tab bar (iOS 26).
private struct GlassTabBarScreen: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            GlassBackdrop()
            let bar = HStack(spacing: 0) {
                tab("house.fill", "Home", selected: true)
                tab("magnifyingglass", "Search", selected: false)
                tab("bell.fill", "Alerts", selected: false)
                tab("person.crop.circle", "Profile", selected: false)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            glassed(bar, in: Capsule()).padding(.horizontal, 20).padding(.bottom, 28)
        }
    }
    private func tab(_ symbol: String, _ title: String, selected: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol).font(.title3)
            Text(title).font(.caption2)
        }
        .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.6)))
        .frame(maxWidth: .infinity)
    }
}

/// Builds a "Real Glass" flow captured via `.hostWindow` (real frosted glass). The Flow Explorer
/// is generated separately (see the note in the test). Run inside the host app.
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
            devices: [.iPhone15Pro], themes: [.light, .dark],
            transitions: [.to("Glass Button Styles")]
        )
        await flow.addScreen(
            title: "Glass Button Styles",
            description: "Real .buttonStyle(.glass) / .glassProminent (iOS 26)",
            view: { GlassButtonStylesScreen() },
            devices: [.iPhone15Pro], themes: [.light, .dark],
            transitions: [.to("Glass Alert")]
        )
        await flow.addScreen(
            title: "Glass Alert",
            description: "An alert with a real glass card + glass buttons",
            view: { GlassAlertScreen() },
            devices: [.iPhone15Pro], themes: [.light, .dark],
            transitions: [.to("Glass Bottom Sheet")]
        )
        await flow.addScreen(
            title: "Glass Bottom Sheet",
            description: "A bottom sheet on a real glass panel",
            view: { GlassBottomSheetScreen() },
            devices: [.iPhone15Pro], themes: [.light, .dark],
            transitions: [.to("Glass Tab Bar")]
        )
        await flow.addScreen(
            title: "Glass Tab Bar",
            description: "A floating Liquid Glass tab bar",
            view: { GlassTabBarScreen() },
            devices: [.iPhone15Pro], themes: [.light, .dark]
        )

        // NOTE: capture only. exportFlowExplorer is intentionally NOT called here — awaiting
        // it inside a host-app async XCTest throws an XCTest `InvalidTransition`. The Flow
        // Explorer is generated from these real-glass baselines by the stable SPM test
        // `ExampleFlowDocumentationTests.testGenerateRealGlassExplorer`.
        print("REAL_GLASS_CAPTURED")
    }
}
