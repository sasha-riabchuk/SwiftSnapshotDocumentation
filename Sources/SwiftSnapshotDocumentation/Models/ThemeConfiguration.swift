//
//  ThemeConfiguration.swift
//  SwiftSnapshotDocumentation
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import SwiftUI

/// Theme configuration for snapshot testing.
///
/// This type defines the color scheme (light or dark mode) that will be
/// applied when capturing snapshots for documentation.
///
/// ## Usage
///
/// ```swift
/// await flow.addScreen(
///     title: "Settings Screen",
///     description: "User preferences",
///     view: { SettingsView() },
///     devices: [.iPhone15Pro],
///     themes: [.light, .dark]  // Capture both themes
/// )
/// ```
///
/// ## Available Themes
///
/// - Light mode (default iOS appearance)
/// - Dark mode (dark appearance)
///
/// - SeeAlso: ``DeviceConfiguration``
public struct ThemeConfiguration: Sendable {
    /// The display name of the theme.
    public let name: String

    /// The SwiftUI color scheme for this theme.
    public let colorScheme: ColorScheme

    /// Creates a custom theme configuration.
    ///
    /// - Parameters:
    ///   - name: The display name for this theme
    ///   - colorScheme: The SwiftUI ColorScheme (.light or .dark)
    public init(name: String, colorScheme: ColorScheme) {
        self.name = name
        self.colorScheme = colorScheme
    }

    // MARK: - Predefined Themes

    /// Light mode appearance (default iOS theme).
    public static let light = ThemeConfiguration(
        name: "light",
        colorScheme: .light
    )

    /// Dark mode appearance.
    public static let dark = ThemeConfiguration(
        name: "dark",
        colorScheme: .dark
    )

    // MARK: - Convenience Collections

    /// Both light and dark modes for comprehensive theme testing.
    public static let allThemes: [ThemeConfiguration] = [.light, .dark]
}

// MARK: - Equatable

extension ThemeConfiguration: Equatable {
    public static func == (lhs: ThemeConfiguration, rhs: ThemeConfiguration) -> Bool {
        lhs.name == rhs.name
    }
}

// MARK: - Hashable

extension ThemeConfiguration: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
