//
//  DocumentedFlow.swift
//  SwiftSnapshotDocumentation
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import Foundation
import SwiftUI
import SnapshotTesting
import XCTest

/// Represents a documented user flow with multiple screens.
///
/// A `DocumentedFlow` is the top-level container for documenting a complete user
/// journey through your app. It captures snapshots of each screen across multiple
/// devices and themes, then generates comprehensive DocC documentation.
///
/// ## Usage
///
/// ```swift
/// @MainActor
/// final class OnboardingFlowDocumentation: XCTestCase {
///     func testGenerateOnboardingDocs() async {
///         let flow = DocumentedFlow(
///             name: "Onboarding",
///             summary: "New user onboarding experience",
///             overview: "Step-by-step guide for new users..."
///         )
///
///         await flow.addScreen(
///             title: "Welcome Screen",
///             description: "App introduction",
///             view: { WelcomeView() },
///             devices: [.iPhone15Pro],
///             themes: [.light, .dark]
///         )
///
///         try await flow.generateDocumentation(
///             outputPath: "Documentation.docc"
///         )
///     }
/// }
/// ```
///
/// - Important: Must be used from a `@MainActor` context (typically within XCTest).
/// - Note: Set `isRecording = true` in your test to generate/update snapshots.
///
/// - SeeAlso: ``DocumentedScreen``
/// - SeeAlso: ``DocumentationConfiguration``
@MainActor
public final class DocumentedFlow {
    /// The name of this flow (used for documentation title).
    public let name: String

    /// A brief one-line summary of the flow.
    public let summary: String

    /// Extended overview in Markdown format.
    public let overview: String

    /// Configuration governing snapshot capture and documentation generation.
    ///
    /// The snapshot-comparison tolerances are read at capture time (when
    /// ``addScreen(title:description:discussion:view:devices:themes:callouts:transitions:file:testName:line:)``
    /// runs), which is why this is supplied here rather than only at generation time.
    public let configuration: DocumentationConfiguration

    /// How snapshots are treated while capturing screens.
    ///
    /// When `nil`, the ambient swift-snapshot-testing configuration is honored (e.g.
    /// a `withSnapshotTesting(record:)` wrapper or test trait). When non-`nil`, each
    /// capture is wrapped to use this mode explicitly. See ``SnapshotRecordMode``.
    public let record: SnapshotRecordMode?

    /// The screens that make up this flow.
    private(set) var screens: [DocumentedScreen] = []

    /// The directory where swift-snapshot-testing wrote this flow's snapshots.
    ///
    /// Derived deterministically from the test's `#file` the first time a screen
    /// is added, so documentation generation reads images from the exact location
    /// they were written to — independent of the process's working directory.
    private(set) var resolvedSnapshotDirectory: String?

    /// Creates a new documented flow.
    ///
    /// - Parameters:
    ///   - name: The flow name (e.g., "Onboarding", "Checkout")
    ///   - summary: Brief one-line summary
    ///   - overview: Extended Markdown overview (optional)
    ///   - configuration: Options for snapshot capture (tolerances, image format)
    ///     and documentation generation. The comparison tolerances take effect as
    ///     screens are captured.
    ///   - record: How snapshots are treated while capturing. Defaults to `nil`,
    ///     which honors the ambient swift-snapshot-testing configuration. Pass
    ///     ``SnapshotRecordMode/verify`` to gate regressions or
    ///     ``SnapshotRecordMode/record`` to (re)generate baselines.
    public init(
        name: String,
        summary: String,
        overview: String = "",
        configuration: DocumentationConfiguration = .init(),
        record: SnapshotRecordMode? = nil
    ) {
        self.name = name
        self.summary = summary
        self.overview = overview
        self.configuration = configuration
        self.record = record
    }

    /// Adds a screen to the flow and captures snapshots.
    ///
    /// This method captures snapshots for all combinations of devices and themes,
    /// then stores the screen configuration for later documentation generation.
    ///
    /// ## Example
    ///
    /// ```swift
    /// await flow.addScreen(
    ///     title: "Profile Screen",
    ///     description: "User profile view",
    ///     discussion: "Displays user info and settings",
    ///     view: { ProfileView() },
    ///     devices: [.iPhone15Pro, .iPadPro129],
    ///     themes: [.light, .dark]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - title: Screen title for documentation
    ///   - description: Brief description
    ///   - discussion: Optional extended discussion (Markdown)
    ///   - view: Closure that builds the view
    ///   - devices: Devices to capture
    ///   - themes: Themes to capture
    ///   - callouts: Optional documentation callouts
    ///   - transitions: Outgoing transitions to other screens (used by the Flow Explorer)
    ///   - file: Source file (automatic)
    ///   - testName: Test function name (automatic)
    ///   - line: Source line (automatic)
    public func addScreen(
        title: String,
        description: String,
        discussion: String? = nil,
        view viewBuilder: @escaping () -> any View,
        devices: [DeviceConfiguration],
        themes: [ThemeConfiguration],
        callouts: [DocumentedScreen.Callout] = [],
        transitions: [ScreenTransition] = [],
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) async {
        let screen = DocumentedScreen(
            title: title,
            description: description,
            discussion: discussion,
            devices: devices,
            themes: themes,
            callouts: callouts,
            transitions: transitions
        )

        screens.append(screen)

        // Record where snapshot-testing will write images for this test, derived
        // from the call site's #file. This matches swift-snapshot-testing's own
        // default layout and removes the need to guess at generation time.
        if resolvedSnapshotDirectory == nil {
            resolvedSnapshotDirectory = Self.snapshotDirectory(forFile: file)
        }

        // Capture snapshots for all device/theme combinations. The view builder is
        // used here and not retained on the screen.
        for device in devices {
            for theme in themes {
                await captureSnapshot(
                    screen: screen,
                    viewBuilder: viewBuilder,
                    device: device,
                    theme: theme,
                    file: file,
                    testName: testName,
                    line: line
                )
            }
        }
    }

    /// Captures a snapshot for a specific screen/device/theme combination.
    ///
    /// - Parameters:
    ///   - screen: The screen to capture
    ///   - viewBuilder: Closure that builds the view (used here, not retained)
    ///   - device: The device configuration
    ///   - theme: The theme configuration
    ///   - file: Source file location
    ///   - testName: Test function name
    ///   - line: Source line number
    private func captureSnapshot(
        screen: DocumentedScreen,
        viewBuilder: () -> any View,
        device: DeviceConfiguration,
        theme: ThemeConfiguration,
        file: StaticString,
        testName: String,
        line: UInt
    ) async {
        #if os(iOS)
        // Mark the view as snapshot-capture so components can substitute effects that
        // don't rasterize offscreen (Liquid Glass, materials, video) — see
        // `EnvironmentValues.isSnapshotCapture`.
        let view = AnyView(viewBuilder())
            .environment(\.isSnapshotCapture, true)
            .preferredColorScheme(theme.colorScheme)

        let screenIndex = screens.count
        let snapshotName = String(format: "%02d-%@-%@-%@",
                                  screenIndex,
                                  screen.id,
                                  device.name,
                                  theme.name)

        let dark = theme.colorScheme == .dark
        let settleDuration = configuration.captureSettleDuration

        let capture = {
            // Host the view in a real UIHostingController and snapshot the *controller*
            // (`.image(on:)`) rather than the bare view (`.image(layout: .device)`).
            // The controller is mounted in a window during capture, so safe-area insets
            // and `.frame(maxWidth/maxHeight: .infinity)` layouts resolve correctly. On
            // iOS 26 the view-only strategy renders such layout-driven screens blank
            // (collapsed safe area); the hosted strategy is byte-identical otherwise.
            // See https://github.com/sasha-riabchuk/SwiftSnapshotDocumentation/issues/2
            let host = UIHostingController(rootView: view)

            // Settle: when configured, mount the host in a live window and pump the run
            // loop so `onAppear`, `.task`, and entrance animations complete before
            // capture. SwiftUI @State persists across the snapshot strategy's own
            // re-mount, so the settled frame is what gets recorded. A duration of 0
            // (default) skips this entirely — identical to prior behavior, so existing
            // baselines are unaffected.
            var settleWindow: UIWindow?
            if settleDuration > 0 {
                let size = device.viewImageConfig.size ?? UIScreen.main.bounds.size
                host.view.frame = CGRect(origin: .zero, size: size)
                host.overrideUserInterfaceStyle = dark ? .dark : .light
                let window = UIWindow(frame: host.view.frame)
                window.overrideUserInterfaceStyle = dark ? .dark : .light
                window.rootViewController = host
                window.makeKeyAndVisible()
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
                RunLoop.main.run(until: Date(timeIntervalSinceNow: settleDuration))
                settleWindow = window
            }

            switch self.configuration.captureMode {
            case .offscreen:
                // Default: offscreen layer render. Device-accurate, works headless, but
                // backdrop effects (Liquid Glass, materials) don't composite — substitute
                // them via `\.isSnapshotCapture`.
                assertSnapshot(
                    of: host,
                    as: .image(
                        on: device.viewImageConfig,
                        precision: self.configuration.snapshotPrecision,
                        perceptualPrecision: self.configuration.snapshotPerceptualPrecision,
                        traits: .init(userInterfaceStyle: dark ? .dark : .light)
                    ),
                    named: snapshotName,
                    file: file,
                    testName: testName,
                    line: line
                )
            case .hostWindow:
                // Real-compositor capture: `drawHierarchy(afterScreenUpdates:)` in the key
                // window, which CAN composite materials / Liquid Glass — but only when the
                // test runs in a host application (it traps otherwise). Free the settle
                // window first so the strategy owns the key window; @State persists.
                settleWindow?.isHidden = true
                settleWindow?.rootViewController = nil
                settleWindow = nil
                host.view.frame = CGRect(origin: .zero, size: device.viewImageConfig.size ?? UIScreen.main.bounds.size)
                let traits = UITraitCollection(traitsFrom: [
                    device.viewImageConfig.traits,
                    UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
                ])
                assertSnapshot(
                    of: host.view,
                    as: .image(
                        drawHierarchyInKeyWindow: true,
                        precision: self.configuration.snapshotPrecision,
                        perceptualPrecision: self.configuration.snapshotPerceptualPrecision,
                        size: device.viewImageConfig.size,
                        traits: traits
                    ),
                    named: snapshotName,
                    file: file,
                    testName: testName,
                    line: line
                )
            }

            // Tear down the settle window after capture.
            settleWindow?.isHidden = true
            settleWindow?.rootViewController = nil
        }

        // Apply the flow's record mode explicitly when set; otherwise honor whatever
        // ambient swift-snapshot-testing configuration is in effect.
        if let record {
            withSnapshotTesting(record: record.configuration, operation: capture)
        } else {
            capture()
        }
        #else
        // Snapshot capture is iOS-only. Generation surfaces a clear
        // DocumentationError.captureUnavailable when no baselines exist.
        print("⚠️  SwiftSnapshotDocumentation: snapshot capture is iOS-only; run on an iOS simulator.")
        #endif
    }

    /// Generates DocC documentation catalog from captured snapshots.
    ///
    /// This method creates a complete DocC documentation catalog including:
    /// - Main catalog file with flow overview
    /// - Individual articles for each screen
    /// - Organized snapshot images
    /// - Navigation and cross-references
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await flow.generateDocumentation(
    ///     outputPath: "Sources/MyModule/Documentation.docc",
    ///     configuration: .init(
    ///         imageFormat: .png,
    ///         createIndexPage: true
    ///     )
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - outputPath: Path where DocC catalog should be created
    ///   - snapshotSourcePath: Optional path to __Snapshots__ directory (auto-detected if nil)
    ///   - configuration: Documentation generation options. Defaults to the
    ///     configuration supplied at the flow's initialization. Note that snapshot
    ///     comparison tolerances are applied at capture time, so overriding them
    ///     here has no effect on already-captured snapshots.
    ///
    /// - Returns: A ``GeneratedCatalog`` with the catalog path and screen/image counts,
    ///   so callers can verify success programmatically. Safe to ignore.
    /// - Throws: ``DocumentationError`` if no snapshots are found (or
    ///   ``DocumentationError/captureUnavailable`` when running off-iOS with no
    ///   pre-recorded snapshots), or file system errors if the catalog can't be written.
    @discardableResult
    public func generateDocumentation(
        outputPath: String,
        snapshotSourcePath: String? = nil,
        configuration: DocumentationConfiguration? = nil
    ) async throws -> GeneratedCatalog {
        let generator = DoCCGenerator(
            flow: self,
            screens: screens,
            snapshotSourcePath: snapshotSourcePath ?? resolvedSnapshotDirectory,
            configuration: configuration ?? self.configuration
        )

        #if os(iOS)
        let captureSupported = true
        #else
        let captureSupported = false
        #endif

        do {
            return try await generator.generate(at: outputPath)
        } catch let error as DocumentationError {
            // On a platform where capture can't run, a "no snapshots" failure is
            // really a platform problem — surface that specifically. If snapshots
            // were found (e.g. committed baselines), generation still succeeds here.
            throw Self.mappedGenerationError(error, captureSupported: captureSupported)
        }
    }

    /// Exports this flow into a Flow Explorer bundle at `explorerPath`.
    ///
    /// Writes `<Name>/{feature.json, flows.js, images/}`, copies the vendored web
    /// bundle (index.html/app.js/vendor) if absent, and rebuilds `manifest.js`.
    /// Shares the capture prerequisite of ``generateDocumentation(outputPath:snapshotSourcePath:configuration:)``:
    /// snapshots must already exist (captured on iOS, or committed baselines).
    ///
    /// - Parameters:
    ///   - explorerPath: Directory where the Flow Explorer bundle is written/updated.
    ///   - snapshotSourcePath: Optional explicit `__Snapshots__` path (auto-resolved if nil).
    ///   - configuration: Generation options; defaults to the flow's configuration.
    /// - Returns: An ``ExportedFeature`` describing what was written.
    /// - Throws: ``DocumentationError`` if snapshots are missing, or
    ///   ``DocumentationError/captureUnavailable`` when running off-iOS with no
    ///   pre-recorded snapshots, or ``DocumentationError/flowExplorerExportFailed(reason:)``
    ///   if the flow has no screens or the bundled web assets are missing.
    @discardableResult
    public func exportFlowExplorer(
        at explorerPath: String,
        snapshotSourcePath: String? = nil,
        configuration: DocumentationConfiguration? = nil
    ) async throws -> ExportedFeature {
        let exporter = FlowExplorerExporter(
            flow: self,
            screens: screens,
            snapshotSourcePath: snapshotSourcePath ?? resolvedSnapshotDirectory,
            configuration: configuration ?? self.configuration
        )
        #if os(iOS)
        let captureSupported = true
        #else
        let captureSupported = false
        #endif
        do {
            return try exporter.export(at: explorerPath)
        } catch let error as DocumentationError {
            throw Self.mappedGenerationError(error, captureSupported: captureSupported)
        }
    }

    /// Maps a generic "no snapshots" generation failure to ``DocumentationError/captureUnavailable``
    /// when snapshot capture isn't supported on the current platform.
    ///
    /// Extracted as a pure function so the mapping is testable independently of the
    /// platform the tests run on.
    nonisolated static func mappedGenerationError(
        _ error: DocumentationError,
        captureSupported: Bool
    ) -> DocumentationError {
        guard !captureSupported else { return error }
        switch error {
        case .snapshotsNotFound, .noSnapshotsCopied:
            return .captureUnavailable
        default:
            return error
        }
    }

    /// Computes the directory swift-snapshot-testing uses for a given test file.
    ///
    /// Mirrors snapshot-testing's default: a `__Snapshots__` directory sitting next
    /// to the test source file, containing a subdirectory named after that file
    /// (without extension). For `/path/MyTests.swift` this returns
    /// `/path/__Snapshots__/MyTests`.
    ///
    /// - Parameter file: The test's `#file` value.
    /// - Returns: The absolute path to the snapshots directory for that file.
    nonisolated static func snapshotDirectory(forFile file: StaticString) -> String {
        let fileURL = URL(fileURLWithPath: "\(file)", isDirectory: false)
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        return fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
            .appendingPathComponent(fileName)
            .path
    }
}

/// Entry points for maintaining a Flow Explorer bundle.
public enum FlowExplorer {
    /// Rebuilds `manifest.js` from the `feature.json` markers in `explorerPath`.
    /// Use once after all documentation tests run to guarantee a complete index.
    ///
    /// - Parameter explorerPath: The Flow Explorer bundle directory to reindex.
    /// - Throws: A file-system error if the directory cannot be read or written.
    @MainActor
    public static func rebuildManifest(at explorerPath: String) throws {
        try FlowExplorerExporter.writeManifest(at: explorerPath, fileManager: .default)
    }
}
