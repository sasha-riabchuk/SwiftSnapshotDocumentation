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
    public init(name: String, summary: String, overview: String = "") {
        self.name = name
        self.summary = summary
        self.overview = overview
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
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) async {
        let screen = DocumentedScreen(
            title: title,
            description: description,
            discussion: discussion,
            viewBuilder: viewBuilder,
            devices: devices,
            themes: themes,
            callouts: callouts
        )

        screens.append(screen)

        // Record where snapshot-testing will write images for this test, derived
        // from the call site's #file. This matches swift-snapshot-testing's own
        // default layout and removes the need to guess at generation time.
        if resolvedSnapshotDirectory == nil {
            resolvedSnapshotDirectory = Self.snapshotDirectory(forFile: file)
        }

        // Capture snapshots for all device/theme combinations
        for device in devices {
            for theme in themes {
                await captureSnapshot(
                    screen: screen,
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
    ///   - device: The device configuration
    ///   - theme: The theme configuration
    ///   - file: Source file location
    ///   - testName: Test function name
    ///   - line: Source line number
    private func captureSnapshot(
        screen: DocumentedScreen,
        device: DeviceConfiguration,
        theme: ThemeConfiguration,
        file: StaticString,
        testName: String,
        line: UInt
    ) async {
        #if os(iOS)
        let view = AnyView(screen.viewBuilder())
            .preferredColorScheme(theme.colorScheme)

        let screenIndex = screens.count
        let snapshotName = String(format: "%02d-%@-%@-%@",
                                  screenIndex,
                                  screen.id,
                                  device.name,
                                  theme.name)

        assertSnapshot(
            of: view,
            as: .image(
                layout: .device(config: device.viewImageConfig),
                traits: .init(userInterfaceStyle: theme.colorScheme == .dark ? .dark : .light)
            ),
            named: snapshotName,
            file: file,
            testName: testName,
            line: line
        )
        #else
        // Snapshot testing for SwiftUI views is iOS-only
        print("⚠️  Snapshot testing is only supported on iOS")
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
    ///   - configuration: Documentation generation options
    ///
    /// - Throws: File system errors if documentation cannot be written
    public func generateDocumentation(
        outputPath: String,
        snapshotSourcePath: String? = nil,
        configuration: DocumentationConfiguration = .init()
    ) async throws {
        let generator = DoCCGenerator(
            flow: self,
            screens: screens,
            snapshotSourcePath: snapshotSourcePath ?? resolvedSnapshotDirectory,
            configuration: configuration
        )

        try await generator.generate(at: outputPath)
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
