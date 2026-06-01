//
//  ModernSwiftUIExampleViews.swift
//  SwiftSnapshotDocumentationExamples
//
//  A showcase of recent SwiftUI features (MeshGradient, Liquid Glass, Gauge, Swift
//  Charts, ContentUnavailableView). Availability-guarded so the target still builds on
//  the iOS 17 / macOS 14 floor, with graceful fallbacks on older OSes.
//
//  Capture note: Liquid Glass (`.glassEffect()`) is a backdrop effect — it renders
//  transparent in an offscreen snapshot, and composites correctly only when captured from
//  a host app (`captureMode: .hostWindow` — see the repo's `HostApp/` target).
//

import SwiftUI
import Charts

// MARK: - Shared mesh backdrop

/// A vibrant 3×3 `MeshGradient` (iOS 18 / macOS 15), falling back to a linear gradient.
struct MeshBackdrop: View {
    var body: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: [
                    .indigo, .purple, .blue,
                    .pink, .cyan, .teal,
                    .orange, .red, .mint
                ]
            )
        } else {
            LinearGradient(colors: [.indigo, .purple, .pink, .orange],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - MeshGradient hero

/// `MeshGradient` (iOS 18 / macOS 15) — a smooth multi-point color mesh. Rasterizes fine.
public struct MeshGradientHeroView: View {
    public init() {}
    public var body: some View {
        ZStack {
            MeshBackdrop().ignoresSafeArea()
            VStack(spacing: 12) {
                Text("MeshGradient")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
                Text("A 3×3 color mesh — SwiftUI, iOS 18")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .padding()
        }
    }
}

// MARK: - Liquid Glass (real API)

/// Real Liquid Glass via `.glassEffect()` (iOS 26 / macOS 26), with an `.ultraThinMaterial`
/// fallback. NOTE: glass samples the backdrop, so an offscreen snapshot shows it transparent
/// (the labels float without their capsule). This screen documents that limitation.
public struct LiquidGlassRealView: View {
    public init() {}
    public var body: some View {
        ZStack {
            MeshBackdrop().ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Liquid Glass")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .shadow(radius: 6)
                glass(Text("Continue").fontWeight(.semibold))
                glass(Text("Maybe Later"))
            }
            .padding(40)
        }
    }

    @ViewBuilder
    private func glass(_ label: some View) -> some View {
        let padded = label
            .foregroundStyle(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 18)
        if #available(iOS 26.0, macOS 26.0, *) {
            padded.glassEffect(.regular, in: .capsule)
        } else {
            padded.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

// MARK: - Gauge + Swift Charts

/// `Gauge` (iOS 16) and a Swift `Charts` bar chart (iOS 16) — both rasterize fine.
public struct GaugesAndChartView: View {
    private struct Day: Identifiable {
        let id = UUID(); let label: String; let steps: Int
    }
    private let week: [Day] = [
        .init(label: "M", steps: 6200), .init(label: "T", steps: 8100),
        .init(label: "W", steps: 7400), .init(label: "T", steps: 9300),
        .init(label: "F", steps: 5600), .init(label: "S", steps: 11200),
        .init(label: "S", steps: 4800)
    ]

    public init() {}
    public var body: some View {
        VStack(spacing: 28) {
            Text("Activity")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 28) {
                Gauge(value: 0.72) {
                    Text("Move")
                } currentValueLabel: {
                    Text("72%")
                }
                .gaugeStyle(.accessoryCircular)
                .tint(Gradient(colors: [.pink, .orange]))

                Gauge(value: 0.45) {
                    Text("Exercise")
                } currentValueLabel: {
                    Text("45%")
                }
                .gaugeStyle(.accessoryCircular)
                .tint(Gradient(colors: [.green, .mint]))

                Gauge(value: 0.9) {
                    Text("Stand")
                } currentValueLabel: {
                    Text("90%")
                }
                .gaugeStyle(.accessoryCircular)
                .tint(Gradient(colors: [.blue, .cyan]))
            }
            .scaleEffect(1.4)
            .frame(height: 90)

            Chart(week) { day in
                BarMark(
                    x: .value("Day", day.label),
                    y: .value("Steps", day.steps)
                )
                .foregroundStyle(.tint)
                .cornerRadius(6)
            }
            .frame(height: 260)

            Spacer()
        }
        .padding(24)
        .tint(.indigo)
    }
}

// MARK: - ContentUnavailableView

/// `ContentUnavailableView` (iOS 17) — the standard empty-state component. Rasterizes fine.
public struct ContentUnavailableExampleView: View {
    public init() {}
    public var body: some View {
        ContentUnavailableView {
            Label("No Bookmarks", systemImage: "bookmark.slash")
        } description: {
            Text("Bookmarks you save will appear here so you can find them later.")
        } actions: {
            Button("Browse Articles") {}
                .buttonStyle(.borderedProminent)
        }
    }
}
