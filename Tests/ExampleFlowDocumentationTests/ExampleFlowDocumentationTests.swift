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
            ]
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
            ]
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

        print("\n✅ Documentation generation complete!")
        print("📖 View documentation:")
        print("   1. Open ExampleFlow.docc in Xcode")
        print("   2. Or build with: xcodebuild docbuild -scheme SwiftSnapshotDocumentation")
    }
}
