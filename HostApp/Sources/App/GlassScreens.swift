import SwiftUI

// MARK: - Liquid Glass screens (presented by the app; captured by the UI test framebuffer)

struct GlassBackdrop: View {
    var body: some View {
        LinearGradient(colors: [.blue, .purple, .pink, .orange], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

@ViewBuilder
func glassed(_ content: some View, in shape: some Shape) -> some View {
    if #available(iOS 26.0, *) { content.glassEffect(.regular, in: shape) }
    else { content.background(.ultraThinMaterial, in: shape) }
}

@ViewBuilder
func glassButton(_ title: String, role: ButtonRole? = nil, prominent: Bool = false) -> some View {
    let b = Button(title, role: role) {}.controlSize(.large)
    if #available(iOS 26.0, *) {
        if prominent { b.buttonStyle(.glassProminent) } else { b.buttonStyle(.glass) }
    } else {
        if prominent { b.buttonStyle(.borderedProminent) } else { b.buttonStyle(.bordered) }
    }
}

struct GlassButtonsScreen: View {
    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 24) {
                Text("Liquid Glass").font(.largeTitle.bold()).foregroundStyle(.white)
                glassButton("Continue", prominent: true).tint(.white)
                glassButton("Maybe Later").tint(.white)
            }
        }
    }
}

struct GlassCardScreen: View {
    var body: some View {
        ZStack {
            GlassBackdrop()
            let card = VStack(alignment: .leading, spacing: 10) {
                Text("Now Playing").font(.title2.bold()).foregroundStyle(.white)
                Text("Liquid Glass adapts to the content behind it, refracting the gradient.")
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(28).frame(width: 320, alignment: .leading)
            glassed(card, in: RoundedRectangle(cornerRadius: 28))
        }
    }
}

struct GlassControlsScreen: View {
    private let icons = ["backward.fill", "play.fill", "forward.fill", "shuffle", "repeat"]
    var body: some View {
        ZStack {
            GlassBackdrop()
            let bar = HStack(spacing: 28) {
                ForEach(icons, id: \.self) { Image(systemName: $0).font(.title2).foregroundStyle(.white) }
            }
            .padding(.horizontal, 28).padding(.vertical, 18)
            glassed(bar, in: Capsule())
        }
    }
}

struct GlassButtonStylesScreen: View {
    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 22) {
                Text(".buttonStyle(.glass)").font(.title2.bold()).foregroundStyle(.white)
                glassButton("Glass")
                glassButton("Glass Prominent", prominent: true)
                glassButton("Delete", role: .destructive, prominent: true)
            }
            .tint(.white).padding(40)
        }
    }
}

struct GlassAlertScreen: View {
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
                    glassButton("Cancel"); glassButton("Delete", role: .destructive, prominent: true)
                }.tint(.white)
            }
            .padding(28).frame(width: 304)
            glassed(alert, in: RoundedRectangle(cornerRadius: 28))
        }
    }
}

struct GlassBottomSheetScreen: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            GlassBackdrop()
            Color.black.opacity(0.12).ignoresSafeArea()
            let sheet = VStack(spacing: 18) {
                Capsule().fill(.white.opacity(0.6)).frame(width: 40, height: 5)
                Text("Share Photo").font(.title3.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        }.frame(maxWidth: .infinity)
    }
}

struct GlassTabBarScreen: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            GlassBackdrop()
            let bar = HStack(spacing: 0) {
                tab("house.fill", "Home", selected: true); tab("magnifyingglass", "Search", selected: false)
                tab("bell.fill", "Alerts", selected: false); tab("person.crop.circle", "Profile", selected: false)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            glassed(bar, in: Capsule()).padding(.horizontal, 20).padding(.bottom, 28)
        }
    }
    private func tab(_ symbol: String, _ title: String, selected: Bool) -> some View {
        VStack(spacing: 3) { Image(systemName: symbol).font(.title3); Text(title).font(.caption2) }
            .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.6)))
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Routing

/// Ordered (id, title) list — the UI test iterates this; the explorer flow mirrors it.
enum GlassCatalog {
    static let screens: [(id: String, title: String)] = [
        ("glass-buttons", "Glass Buttons"),
        ("glass-card", "Glass Card"),
        ("glass-controls", "Glass Controls"),
        ("glass-button-styles", "Glass Button Styles"),
        ("glass-alert", "Glass Alert"),
        ("glass-bottom-sheet", "Glass Bottom Sheet"),
        ("glass-tab-bar", "Glass Tab Bar"),
    ]
}

/// Presents the glass screen named by the `-glassScreen <id>` launch argument.
struct GlassRouter: View {
    let id: String
    var body: some View {
        switch id {
        case "glass-buttons": GlassButtonsScreen()
        case "glass-card": GlassCardScreen()
        case "glass-controls": GlassControlsScreen()
        case "glass-button-styles": GlassButtonStylesScreen()
        case "glass-alert": GlassAlertScreen()
        case "glass-bottom-sheet": GlassBottomSheetScreen()
        case "glass-tab-bar": GlassTabBarScreen()
        default: Color.black.ignoresSafeArea()
        }
    }
}
