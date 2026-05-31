//
//  DocumentedScreen.swift
//  SwiftSnapshotDocumentation
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import Foundation

/// Represents a single screen in a documented user flow.
///
/// A documented screen captures the visual appearance and behavior of a specific
/// view state across multiple devices and themes. Each screen generates snapshots
/// and corresponding DocC articles for comprehensive documentation.
///
/// ## Usage
///
/// Screens are typically added to a ``DocumentedFlow`` using the `addScreen` method:
///
/// ```swift
/// await flow.addScreen(
///     title: "Login Screen",
///     description: "User authentication entry point",
///     discussion: """
///     This screen provides two login options:
///     - Email and password
///     - Sign in with Apple
///     """,
///     view: { LoginView() },
///     devices: [.iPhone15Pro, .iPadPro129],
///     themes: [.light, .dark],
///     callouts: [
///         .init(type: .note, content: "Password requirements shown below field")
///     ]
/// )
/// ```
///
/// - SeeAlso: ``DocumentedFlow``
/// - SeeAlso: ``Callout``
/// This type only describes a screen; it does not hold the SwiftUI view. The view
/// is supplied to ``DocumentedFlow/addScreen(title:description:discussion:view:devices:themes:callouts:file:testName:line:)``
/// and consumed immediately during snapshot capture, so the long-lived screen value
/// stays a plain, `Sendable` metadata record rather than retaining a closure (and
/// whatever state it captures) for the lifetime of the flow.
public struct DocumentedScreen: Sendable {
    /// Unique identifier for this screen (derived from title if not provided).
    public let id: String

    /// The display title of this screen.
    public let title: String

    /// A brief one-line description of the screen's purpose.
    public let description: String

    /// Optional extended discussion in Markdown format.
    ///
    /// This content appears in the generated DocC article's "Discussion" section.
    /// Supports full Markdown syntax including headers, lists, code blocks, etc.
    public let discussion: String?

    /// The devices on which to capture this screen.
    public let devices: [DeviceConfiguration]

    /// The themes (light/dark) in which to capture this screen.
    public let themes: [ThemeConfiguration]

    /// Optional callouts to include in the documentation.
    public let callouts: [Callout]

    /// Creates a documented screen.
    ///
    /// - Parameters:
    ///   - id: Optional unique identifier (defaults to sanitized title)
    ///   - title: The screen's display title
    ///   - description: Brief one-line description
    ///   - discussion: Optional extended Markdown discussion
    ///   - devices: Devices to capture
    ///   - themes: Themes to capture
    ///   - callouts: Optional documentation callouts
    public init(
        id: String? = nil,
        title: String,
        description: String,
        discussion: String? = nil,
        devices: [DeviceConfiguration],
        themes: [ThemeConfiguration],
        callouts: [Callout] = []
    ) {
        self.id = id ?? title.sanitizedForFilename()
        self.title = title
        self.description = description
        self.discussion = discussion
        self.devices = devices
        self.themes = themes
        self.callouts = callouts
    }

    /// A documentation callout that highlights important information.
    ///
    /// Callouts appear as styled boxes in the generated DocC articles to draw
    /// attention to specific details, warnings, tips, etc.
    ///
    /// ## Example
    ///
    /// ```swift
    /// Callout(
    ///     type: .important,
    ///     content: "This action cannot be undone"
    /// )
    /// ```
    public struct Callout: Sendable {
        /// The type of callout, which determines its visual styling.
        public enum CalloutType: String, Sendable {
            /// Informational note (blue styling).
            case note = "Note"

            /// Important information requiring attention (yellow styling).
            case important = "Important"

            /// Warning about potential issues (red styling).
            case warning = "Warning"

            /// Helpful tip or suggestion (green styling).
            case tip = "Tip"

            /// Experiment or try-it-yourself suggestion.
            case experiment = "Experiment"
        }

        /// The callout type.
        public let type: CalloutType

        /// The content/message of the callout (Markdown supported).
        public let content: String

        /// Creates a documentation callout.
        ///
        /// - Parameters:
        ///   - type: The callout type
        ///   - content: The callout message (Markdown supported)
        public init(type: CalloutType, content: String) {
            self.type = type
            self.content = content
        }
    }
}

// MARK: - String Extensions

extension String {
    /// Sanitizes a string to be safe for use as a filename.
    ///
    /// This method:
    /// - Converts to lowercase
    /// - Replaces spaces and special chars with hyphens
    /// - Removes all non-alphanumeric characters except hyphens
    /// - Collapses multiple consecutive hyphens into single hyphen
    ///
    /// - Returns: A filename-safe version of the string
    func sanitizedForFilename() -> String {
        self
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
    }
}
