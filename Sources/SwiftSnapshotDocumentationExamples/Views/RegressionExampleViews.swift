//
//  RegressionExampleViews.swift
//  SwiftSnapshotDocumentationExamples
//
//  Screens that reproduce the capture bugs this library has fixed, so the example
//  suite verifies they keep rendering (non-blank) rather than only asserting it once.
//
//  - LayoutDrivenRegressionView: full-bleed background + top-aligned text + an
//    `.infinity` frame with no large intrinsic child. On iOS 26 the old view-only
//    capture (`.image(layout: .device)`) rendered this BLANK (collapsed safe area);
//    fixed in 1.2.2 by hosting in a UIHostingController. See issue #2.
//  - EntranceAnimationRegressionView: content revealed by `onAppear { withAnimation }`
//    from `opacity 0`. A single synchronous capture records the hidden first frame
//    (blank); fixed in 1.3.0 by `DocumentationConfiguration.captureSettleDuration`.
//

import SwiftUI

/// Reproduces issue #2: a layout-driven screen that collapsed to blank under the old
/// view-only capture strategy on iOS 26.
public struct LayoutDrivenRegressionView: View {
    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Get Started")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                Text("A full-bleed, top-aligned, .infinity layout")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.top, 80)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Reproduces the entrance-animation blank: the whole screen fades in via
/// `onAppear { withAnimation { … } }`, so a synchronous capture records it hidden.
/// Requires `captureSettleDuration` > the animation duration to render.
public struct EntranceAnimationRegressionView: View {
    @State private var shown = false

    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange, Color.red],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Now You See Me")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                Text("Revealed by an onAppear entrance animation")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
        }
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) { shown = true }
        }
    }
}
