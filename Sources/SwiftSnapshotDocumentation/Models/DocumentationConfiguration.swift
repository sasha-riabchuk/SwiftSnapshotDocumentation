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
    /// - Note: Currently controlled by PointFree's snapshot-testing configuration
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
    public init(
        imageFormat: ImageFormat = .png,
        deviceFrames: Bool = true,
        perPixelTolerance: Float = 0.01,
        overallTolerance: Float = 0.05,
        createIndexPage: Bool = true,
        includeFlowDiagram: Bool = false,
        organizeByDevice: Bool = false
    ) {
        self.imageFormat = imageFormat
        self.deviceFrames = deviceFrames
        self.perPixelTolerance = perPixelTolerance
        self.overallTolerance = overallTolerance
        self.createIndexPage = createIndexPage
        self.includeFlowDiagram = includeFlowDiagram
        self.organizeByDevice = organizeByDevice
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
