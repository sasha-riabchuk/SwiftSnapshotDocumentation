//
//  ExampleFlowDocumentationTests.swift
//  SwiftSnapshotDocumentationExamples
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import XCTest
import SwiftSnapshotDocumentation
import SwiftSnapshotDocumentationExamples

/// Example test demonstrating how to generate flow documentation.
///
/// This test serves as both a proof-of-concept and usage example for the
/// SwiftSnapshotDocumentation package.
///
/// ## Usage
///
/// 1. By default the test verifies against committed snapshots (regression gate).
/// 2. To (re)generate snapshots, set the `RECORD_SNAPSHOTS` scheme environment
///    variable so the flow uses ``SnapshotRecordMode/record``, then re-run.
/// 3. Check the generated `ExampleFlow.docc` catalog.
/// 4. View in Xcode's documentation viewer or build with `docc`.
///
/// ## Generated Output
///
/// - `ExampleFlow.docc/` - DocC catalog
/// - `ExampleFlow.docc/ExampleFlow.md` - Main documentation page
/// - `ExampleFlow.docc/01-*.md` - Individual screen articles
/// - `ExampleFlow.docc/Resources/Snapshots/` - Screenshot images
@MainActor
final class ExampleFlowDocumentationTests: XCTestCase {

    func testGenerateExampleFlowDocumentation() async throws {
        // Recording is opt-in. By default the flow VERIFIES against committed
        // snapshots, so this test gates UI regressions (it fails if a screen
        // changed). To regenerate the baselines + catalog, set the RECORD_SNAPSHOTS
        // environment variable, then commit the result. Recording runs intentionally
        // report a failure to remind you to review and re-run.
        //
        // Set RECORD_SNAPSHOTS in the test's scheme/test-plan environment (a plain
        // shell variable passed to `xcodebuild` does not reach the simulator test
        // process). Recording reports a failure for each snapshot by design.
        let isRecording = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil

        // Create the documented flow
        let flow = DocumentedFlow(
            name: "ExampleFlow",
            summary: "Example user onboarding and authentication flow",
            overview: """
            This example demonstrates the capabilities of SwiftSnapshotDocumentation.

            ## Flow Steps

            1. **Welcome Screen** - Initial landing page
            2. **Login Screen** - User authentication
            3. **Profile Form** - Multiple states (empty, filled, loading)

            ## Coverage

            - iPhone and iPad layouts
            - Light and Dark mode
            - Multiple view states
            - Documentation with callouts

            > Note: This is a demonstration flow showing the package capabilities.
            """,
            record: isRecording ? .record : .verify
        )

        // MARK: - Step 1: Welcome Screen

        await flow.addScreen(
            title: "Welcome Screen",
            description: "Initial landing page introducing users to the app",
            discussion: """
            The welcome screen is the entry point for new users. It features:

            - Eye-catching gradient background
            - App icon/branding
            - Clear call-to-action button

            ## Design Notes

            The gradient uses blue and purple colors to create a modern,
            welcoming appearance. The "Get Started" button uses a frosted
            glass effect (`.ultraThinMaterial`) for visual appeal.

            ## User Flow

            When users tap "Get Started", they proceed to the login screen.
            """,
            view: {
                WelcomeExampleView()
            },
            devices: [.iPhone15Pro, .iPadPro129],
            themes: [.light, .dark],
            callouts: [
                .init(
                    type: .tip,
                    content: "The gradient adapts to light/dark mode automatically"
                )
            ],
            transitions: [.to("Login Screen")]
        )

        // MARK: - Step 2: Login Screen

        await flow.addScreen(
            title: "Login Screen",
            description: "User authentication with email/password and Apple Sign-In",
            discussion: """
            The login screen provides two authentication methods:

            1. **Email and Password** - Traditional login
            2. **Sign in with Apple** - Quick, privacy-focused option

            ## Form Validation

            - Email field uses `.emailAddress` keyboard type
            - Password field is secured
            - Both fields support autofill

            ## Accessibility

            All form fields have proper labels and support VoiceOver navigation.
            """,
            view: {
                LoginExampleView()
            },
            devices: [.iPhone15Pro, .iPadPro129],
            themes: [.light, .dark],
            callouts: [
                .init(
                    type: .important,
                    content: "Sign in with Apple is the recommended authentication method"
                ),
                .init(
                    type: .note,
                    content: "The forgot password link opens a password reset flow"
                )
            ],
            transitions: [.to("Profile Form - Empty", on: "new user")]
        )

        // MARK: - Step 3: Profile Form - Empty State

        await flow.addScreen(
            title: "Profile Form - Empty",
            description: "Empty profile form requiring user input",
            discussion: """
            This state appears when no profile data is available from:
            - Apple Sign-In
            - Previous sessions
            - Firebase Auth

            Users must enter both first and last name to continue.
            The "Continue" button is disabled until both fields are filled.
            """,
            view: {
                ProfileFormExampleView()
            },
            devices: [.iPhone15Pro, .iPadPro129],
            themes: [.light, .dark],
            callouts: [
                .init(
                    type: .note,
                    content: "The Continue button is disabled when fields are empty"
                )
            ]
        )

        // MARK: - Step 4: Profile Form - Filled

        await flow.addScreen(
            title: "Profile Form - Filled",
            description: "Profile form with pre-filled data",
            discussion: """
            When data is available from Apple Sign-In or Firebase, the form
            is automatically pre-filled with the user's name.

            ## Data Sources

            - **Apple Sign-In**: Provides name on first login only
            - **Firebase Auth**: Display name from previous sessions
            - **Manual Entry**: User input

            The form indicates the data source with informational text.
            """,
            view: {
                ProfileFormExampleView(
                    firstName: "Jane",
                    lastName: "Smith"
                )
            },
            devices: [.iPhone15Pro, .iPadPro129],
            themes: [.light, .dark],
            callouts: [
                .init(
                    type: .tip,
                    content: "Pre-filled data can still be edited by the user"
                )
            ]
        )

        // MARK: - Step 5: Profile Form - Loading

        await flow.addScreen(
            title: "Profile Form - Loading",
            description: "Loading state while saving profile data",
            discussion: """
            While the profile is being saved to the server, the form enters
            a loading state:

            - Progress indicator appears in the button
            - Form fields are disabled
            - User cannot navigate away

            This prevents duplicate submissions and provides clear feedback.
            """,
            view: {
                ProfileFormExampleView(
                    firstName: "Jane",
                    lastName: "Smith",
                    isLoading: true
                )
            },
            devices: [.iPhone15Pro],
            themes: [.light, .dark],
            callouts: [
                .init(
                    type: .warning,
                    content: "Ensure loading states timeout after 30 seconds"
                )
            ]
        )

        // MARK: - Generate Documentation

        print("\n📚 Generating DocC documentation...")

        try await flow.generateDocumentation(
            outputPath: "ExampleFlow.docc",
            configuration: .init(
                imageFormat: .png,
                deviceFrames: true,
                createIndexPage: true,
                includeFlowDiagram: false
            )
        )

        let exported = try await flow.exportFlowExplorer(at: "FlowExplorer")
        print("🗂  Flow Explorer: \(exported.screenCount) screens, \(exported.edgeCount) edges at \(exported.featurePath)")

        print("\n✅ Documentation generation complete!")
        print("📖 View documentation:")
        print("   1. Open ExampleFlow.docc in Xcode")
        print("   2. Or build with: xcodebuild docbuild -scheme SwiftSnapshotDocumentation")
    }

    /// A gallery of native iOS components, exported as a second feature into the same
    /// Flow Explorer bundle (so the explorer sidebar lists both features).
    func testGenerateIOSComponentsFlow() async throws {
        let isRecording = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil

        let flow = DocumentedFlow(
            name: "iOS Components",
            summary: "Native iOS UI components, rendered for documentation",
            overview: """
            A reference gallery of common native iOS components. Overlay components
            (alert, action sheet, sheets, popover, toast) are rendered inline as their
            presented appearance, since native presentations live in a separate window
            and aren't captured by view snapshots. Tab bar and navigation bar use the
            real `TabView` / `NavigationStack`.
            """,
            record: isRecording ? .record : .verify
        )

        let devices: [DeviceConfiguration] = [.iPhone15Pro]
        let themes: [ThemeConfiguration] = [.light, .dark]

        await flow.addScreen(title: "Alert", description: "A modal alert (UIAlertController) with destructive action",
                             view: { AlertComponentView() }, devices: devices, themes: themes,
                             callouts: [.init(type: .note, content: "Rendered inline — native `.alert` presents in a separate window")])
        await flow.addScreen(title: "Action Sheet", description: "A confirmation dialog anchored to the bottom",
                             view: { ActionSheetComponentView() }, devices: devices, themes: themes)
        await flow.addScreen(title: "Half Sheet", description: "A sheet at the medium detent with a grabber",
                             view: { HalfSheetComponentView() }, devices: devices, themes: themes)
        await flow.addScreen(title: "Full Screen Cover", description: "A full-screen modal with Cancel / Send",
                             view: { FullScreenCoverComponentView() }, devices: devices, themes: themes)
        await flow.addScreen(title: "Popover", description: "A popover menu attached to a source view",
                             view: { PopoverComponentView() }, devices: devices, themes: themes)
        await flow.addScreen(title: "Tab Bar", description: "A real TabView with a bottom tab bar",
                             view: { TabBarComponentView() }, devices: devices, themes: themes,
                             callouts: [.init(type: .tip, content: "Uses a real `TabView` — it's part of the view tree, so it snapshots directly")])
        await flow.addScreen(title: "Navigation Bar", description: "A NavigationStack with a large title and toolbar",
                             view: { NavBarComponentView() }, devices: devices, themes: themes)
        await flow.addScreen(title: "Toast", description: "A transient banner / toast notification",
                             view: { ToastComponentView() }, devices: devices, themes: themes)

        let exported = try await flow.exportFlowExplorer(at: "FlowExplorer")
        print("🗂  iOS Components: \(exported.screenCount) screens at \(exported.featurePath)")
    }

    /// Regression flow: documents the exact screens that the capture bugs produced blank,
    /// so the suite verifies they keep rendering instead of asserting it only once.
    ///
    /// - `Layout-Driven Screen` — issue #2 (1.2.2): full-bleed, top-aligned, `.infinity`
    ///   layout that collapsed to blank under the old view-only capture on iOS 26.
    /// - `Entrance Animation` — (1.3.0): a screen revealed by `onAppear { withAnimation }`
    ///   that captured as its hidden first frame. Rendered correctly here because the flow
    ///   sets `captureSettleDuration` longer than the animation.
    ///
    /// If either regresses, the committed baselines won't match a blank capture and this
    /// test fails. Recorded with `captureSettleDuration: 0.8`.
    func testGenerateRegressionFlow() async throws {
        let isRecording = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil

        let flow = DocumentedFlow(
            name: "Regression",
            summary: "Screens that previously captured blank, now verified",
            overview: """
            Regression coverage for capture bugs this library has fixed: layout-driven
            screens that collapsed on iOS 26 (issue #2), and entrance-animated screens
            captured before their reveal completed. Both render here; the committed
            baselines guard against either regressing back to blank.
            """,
            configuration: .init(captureSettleDuration: 0.8),
            record: isRecording ? .record : .verify
        )

        await flow.addScreen(
            title: "Layout-Driven Screen",
            description: "Full-bleed gradient + top-aligned text + .infinity frame (issue #2)",
            discussion: "Rendered blank under the old view-only capture on iOS 26; fixed in 1.2.2 by hosting in a UIHostingController.",
            view: { LayoutDrivenRegressionView() },
            devices: [.iPhone15Pro],
            themes: [.light, .dark],
            callouts: [.init(type: .note, content: "This layout collapsed to blank before 1.2.2")],
            transitions: [.to("Entrance Animation")]
        )

        await flow.addScreen(
            title: "Entrance Animation",
            description: "Content revealed by onAppear { withAnimation } from opacity 0",
            discussion: "A synchronous capture recorded the hidden first frame; captureSettleDuration (1.3.0) lets the reveal complete first.",
            view: { EntranceAnimationRegressionView() },
            devices: [.iPhone15Pro],
            themes: [.light, .dark],
            callouts: [.init(type: .tip, content: "Captured with captureSettleDuration: 0.8")]
        )

        let exported = try await flow.exportFlowExplorer(at: "FlowExplorer")
        print("🗂  Regression: \(exported.screenCount) screens at \(exported.featurePath)")
    }
}
