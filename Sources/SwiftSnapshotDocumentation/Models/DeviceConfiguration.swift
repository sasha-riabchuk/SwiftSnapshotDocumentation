//
//  DeviceConfiguration.swift
//  SwiftSnapshotDocumentation
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

import SnapshotTesting

/// Device configurations for snapshot testing.
///
/// This type provides predefined device configurations that can be used when
/// capturing snapshots for documentation. Each configuration includes the
/// appropriate view image settings for the specified device.
///
/// ## Usage
///
/// ```swift
/// await flow.addScreen(
///     title: "Welcome Screen",
///     description: "App entry point",
///     view: { WelcomeView() },
///     devices: [.iPhone15Pro, .iPadPro129],
///     themes: [.light, .dark]
/// )
/// ```
///
/// ## Available Devices
///
/// - iPhone SE (compact)
/// - iPhone 15 Pro (standard)
/// - iPhone 15 Pro Max (large)
/// - iPad Pro 11"
/// - iPad Pro 12.9"
///
/// - SeeAlso: ``ThemeConfiguration``
@available(iOS 17.0, *)
public struct DeviceConfiguration: Sendable {
    /// The display name of the device.
    public let name: String

    /// The view image configuration for snapshot testing.
    #if os(iOS)
    public let viewImageConfig: ViewImageConfig
    #else
    public let viewImageConfig: Any
    #endif

    /// The bezel geometry used when ``DocumentationConfiguration/deviceFrames`` is enabled.
    public let frame: DeviceFrame

    /// Creates a custom device configuration.
    ///
    /// - Parameters:
    ///   - name: The display name for this device
    ///   - viewImageConfig: The PointFree ViewImageConfig for this device
    ///   - frame: The bezel geometry for device-framed documentation images
    #if os(iOS)
    public init(name: String, viewImageConfig: ViewImageConfig, frame: DeviceFrame = .phone) {
        self.name = name
        self.viewImageConfig = viewImageConfig
        self.frame = frame
    }
    #else
    public init(name: String, viewImageConfig: Any, frame: DeviceFrame = .phone) {
        self.name = name
        self.viewImageConfig = viewImageConfig
        self.frame = frame
    }
    #endif

    // MARK: - Predefined iPhone Devices

    #if os(iOS)
    /// iPhone SE (2nd/3rd generation) - 4.7" display, compact size.
    ///
    /// Home-button era, so it is framed without a notch.
    public static let iPhoneSE = DeviceConfiguration(
        name: "iPhoneSE",
        viewImageConfig: .iPhoneSe,
        frame: DeviceFrame(bezelFraction: 0.06, screenCornerFraction: 0.02, notch: .none)
    )

    /// iPhone 15 Pro - 6.1" display, standard size.
    public static let iPhone15Pro = DeviceConfiguration(
        name: "iPhone15Pro",
        viewImageConfig: .iPhone13Pro,  // Using closest available
        frame: .phone
    )

    /// iPhone 15 Pro Max - 6.7" display, large size.
    public static let iPhone15ProMax = DeviceConfiguration(
        name: "iPhone15ProMax",
        viewImageConfig: .iPhone13ProMax,  // Using closest available
        frame: .phone
    )

    // MARK: - Predefined iPad Devices

    /// iPad Pro 11" - Compact iPad form factor.
    public static let iPadPro11 = DeviceConfiguration(
        name: "iPadPro11",
        viewImageConfig: .iPadPro11,
        frame: .pad
    )

    /// iPad Pro 12.9" - Large iPad form factor.
    public static let iPadPro129 = DeviceConfiguration(
        name: "iPadPro129",
        viewImageConfig: .iPadPro12_9,
        frame: .pad
    )
    #endif

    // MARK: - Convenience Collections

    #if os(iOS)
    /// All iPhone devices for comprehensive testing.
    public static let allIPhones: [DeviceConfiguration] = [
        .iPhoneSE,
        .iPhone15Pro,
        .iPhone15ProMax
    ]

    /// All iPad devices for comprehensive testing.
    public static let allIPads: [DeviceConfiguration] = [
        .iPadPro11,
        .iPadPro129
    ]

    /// All devices for maximum coverage.
    public static let allDevices: [DeviceConfiguration] = allIPhones + allIPads
    #endif
}

// MARK: - Equatable

extension DeviceConfiguration: Equatable {
    public static func == (lhs: DeviceConfiguration, rhs: DeviceConfiguration) -> Bool {
        lhs.name == rhs.name
    }
}

// MARK: - Hashable

extension DeviceConfiguration: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
