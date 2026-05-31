//
//  SnapshotCaptureEnvironment.swift
//  SwiftSnapshotDocumentation
//
//  A SwiftUI environment flag that is `true` only while a view is being rendered
//  for snapshot capture by `DocumentedFlow`. Components can read it to substitute
//  effects that don't rasterize in offscreen snapshots — Liquid Glass
//  (`.glassEffect()`), blur materials, video/`AVPlayerLayer`, Metal — with a
//  documentation-friendly stand-in (a solid fill, a poster frame).
//

import SwiftUI

private struct SnapshotCaptureKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Whether the view is currently being rendered for documentation snapshot capture.
    ///
    /// `DocumentedFlow` sets this to `true` on the hosted view while it captures each
    /// snapshot; it is `false` everywhere else (normal app runtime, previews, live UI).
    ///
    /// Use it to substitute appearances that don't survive an offscreen snapshot pass.
    /// Compositor-backed effects — Liquid Glass (`.glassEffect()`), `.regularMaterial`
    /// and other blur materials, `VideoPlayer` / `AVPlayerLayer`, Metal/SceneKit — render
    /// transparent or blank when captured offscreen. Swap them for a static stand-in when
    /// this flag is set:
    ///
    /// ```swift
    /// struct ProminentActionButton: View {
    ///     @Environment(\.isSnapshotCapture) private var isSnapshotCapture
    ///     var body: some View {
    ///         label
    ///             .background {
    ///                 if isSnapshotCapture {
    ///                     Capsule().fill(.tint)            // renders in snapshots
    ///                 } else {
    ///                     Capsule().glassEffect(.regular)  // real Liquid Glass at runtime
    ///                 }
    ///             }
    ///     }
    /// }
    /// ```
    ///
    /// - Note: The flag is only ever set during capture, which is iOS-only. On other
    ///   platforms, and at app runtime, it reads `false`.
    var isSnapshotCapture: Bool {
        get { self[SnapshotCaptureKey.self] }
        set { self[SnapshotCaptureKey.self] = newValue }
    }
}
