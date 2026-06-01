//
//  DocumentationConfiguration.swift
//  SwiftSnapshotDocumentation
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import Foundation

/// Configuration options for DocC documentation generation.
///
/// This type controls various aspects of how the DocC catalog is generated,
/// including image formats, organization, and optional features.
///
/// ## Usage
///
/// ```swift
/// let config = DocumentationConfiguration(
///     imageFormat: .png,
///     createIndexPage: true,
///     includeFlowDiagram: true
/// )
///
/// try await flow.generateDocumentation(
///     outputPath: "Documentation.docc",
///     configuration: config
/// )
/// ```
///
/// - SeeAlso: ``DocumentedFlow/generateDocumentation(outputPath:configuration:)``
public struct DocumentationConfiguration: Sendable {
    /// The image format for captured snapshots.
    public enum ImageFormat: String, Sendable {
        /// PNG format (lossless, larger files, better quality).
        case png = "png"

        /// JPEG format (lossy, smaller files).
        case jpeg = "jpg"
    }

    /// The image format to use for snapshots.
    ///
    /// - Default: `.png`
    public let imageFormat: ImageFormat

    /// Whether to include device bezels/frames around screenshots.
    ///
    /// When `true`, screenshots include the device frame showing bezels,
    /// notches, and physical device appearance.
    ///
    /// - Default: `true`
    public let deviceFrames: Bool

    /// Pixel-level tolerance for snapshot comparisons.
    ///
    /// - Default: `0.01` (1% tolerance)
    /// - Note: Used by snapshot-testing for comparison accuracy
    public let perPixelTolerance: Float

    /// Overall image tolerance for snapshot comparisons.
    ///
    /// - Default: `0.05` (5% tolerance)
    /// - Note: Used by snapshot-testing for comparison accuracy
    public let overallTolerance: Float

    /// Whether to create an index/landing page for the documentation.
    ///
    /// When `true`, generates a main documentation page listing all screens
    /// with navigation links.
    ///
    /// - Default: `true`
    public let createIndexPage: Bool

    /// Whether to include a visual flow diagram in the documentation.
    ///
    /// When `true`, attempts to generate a Mermaid diagram showing the
    /// flow between screens.
    ///
    /// - Default: `false`
    /// - Note: Requires screens to have explicit navigation relationships
    public let includeFlowDiagram: Bool

    /// Whether to organize images by device in the Resources folder.
    ///
    /// When `true`, creates subfolders like `Resources/iPhone15Pro/`, `Resources/iPadPro129/`.
    /// When `false`, all images go directly into `Resources/Snapshots/`.
    ///
    /// - Default: `false`
    public let organizeByDevice: Bool

    /// How long (in seconds) to let a screen *settle* in a live window before capturing.
    ///
    /// A snapshot records a single synchronous frame. Screens whose content is
    /// revealed by an entrance animation — e.g. `onAppear { withAnimation { … } }`
    /// starting from `opacity 0`, an offset, or a scale — are otherwise captured at
    /// the *start* of that animation, i.e. fully hidden (a blank/white image).
    ///
    /// When this is greater than `0`, the view is hosted in a real `UIWindow`
    /// (matching the device's size, safe-area insets, and traits) and the main run
    /// loop is pumped for this duration so `onAppear`, `.task`, and entrance
    /// animations complete, then the *settled* frame is captured.
    ///
    /// - Default: `0` (capture synchronously — identical to prior behavior; existing
    ///   baselines are unaffected). Set to slightly more than your longest entrance
    ///   animation (e.g. `0.6`–`1.0`).
    /// - Note: iOS-only; ignored on other platforms. Enabling it produces new
    ///   baselines for animated screens, so re-record after turning it on.
    public let captureSettleDuration: TimeInterval

    /// Creates a documentation configuration with default values.
    ///
    /// - Parameters:
    ///   - imageFormat: Image format (default: `.png`)
    ///   - deviceFrames: Include device bezels (default: `true`)
    ///   - perPixelTolerance: Pixel tolerance (default: `0.01`)
    ///   - overallTolerance: Overall tolerance (default: `0.05`)
    ///   - createIndexPage: Create index page (default: `true`)
    ///   - includeFlowDiagram: Include flow diagram (default: `false`)
    ///   - organizeByDevice: Organize images by device (default: `false`)
    ///   - captureSettleDuration: Seconds to let entrance animations settle before
    ///     capture (default: `0` — synchronous capture, existing behavior)
    public init(
        imageFormat: ImageFormat = .png,
        deviceFrames: Bool = true,
        perPixelTolerance: Float = 0.01,
        overallTolerance: Float = 0.05,
        createIndexPage: Bool = true,
        includeFlowDiagram: Bool = false,
        organizeByDevice: Bool = false,
        captureSettleDuration: TimeInterval = 0
    ) {
        self.imageFormat = imageFormat
        self.deviceFrames = deviceFrames
        self.perPixelTolerance = perPixelTolerance
        self.overallTolerance = overallTolerance
        self.createIndexPage = createIndexPage
        self.includeFlowDiagram = includeFlowDiagram
        self.organizeByDevice = organizeByDevice
        self.captureSettleDuration = captureSettleDuration
    }
}

// MARK: - Snapshot comparison mapping

extension DocumentationConfiguration {
    /// The `precision` value passed to swift-snapshot-testing's `.image` strategy:
    /// the fraction of pixels that must match, i.e. `1 - overallTolerance`.
    ///
    /// Clamped to `0...1`.
    var snapshotPrecision: Float {
        (1 - overallTolerance).clampedToUnitInterval
    }

    /// The `perceptualPrecision` value passed to swift-snapshot-testing's `.image`
    /// strategy: how closely each individual pixel must match, i.e.
    /// `1 - perPixelTolerance`.
    ///
    /// Clamped to `0...1`.
    var snapshotPerceptualPrecision: Float {
        (1 - perPixelTolerance).clampedToUnitInterval
    }
}

private extension Float {
    var clampedToUnitInterval: Float {
        Swift.min(1, Swift.max(0, self))
    }
}
