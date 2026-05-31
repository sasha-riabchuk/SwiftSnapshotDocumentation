//
//  DeviceFrame.swift
//  SwiftSnapshotDocumentation
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import CoreGraphics

/// Geometry describing a procedurally-drawn device bezel composited around a
/// captured screenshot when ``DocumentationConfiguration/deviceFrames`` is enabled.
///
/// Values are expressed as fractions of the screenshot's shorter side so the same
/// frame looks consistent across resolutions and `@2x`/`@3x` scales. This renders a
/// generic, recognizable device shape (no bundled proprietary device artwork).
public struct DeviceFrame: Sendable, Equatable {
    /// The shape of the top sensor housing drawn over the screen.
    public enum Notch: Sendable, Equatable {
        /// No cutout (e.g. iPad).
        case none
        /// A centered pill, as on Dynamic Island / notch iPhones.
        case island
    }

    /// Bezel thickness, as a fraction of the screenshot's shorter side.
    public var bezelFraction: CGFloat

    /// Screen corner radius, as a fraction of the screenshot's shorter side.
    public var screenCornerFraction: CGFloat

    /// The top sensor-housing style drawn over the screen.
    public var notch: Notch

    /// Creates a device frame description.
    ///
    /// - Parameters:
    ///   - bezelFraction: Bezel thickness as a fraction of the shorter side.
    ///   - screenCornerFraction: Screen corner radius as a fraction of the shorter side.
    ///   - notch: The top sensor-housing style.
    public init(
        bezelFraction: CGFloat = 0.04,
        screenCornerFraction: CGFloat = 0.09,
        notch: Notch = .island
    ) {
        self.bezelFraction = bezelFraction
        self.screenCornerFraction = screenCornerFraction
        self.notch = notch
    }

    /// A modern iPhone-style frame with rounded screen corners and a Dynamic Island.
    public static let phone = DeviceFrame(
        bezelFraction: 0.04,
        screenCornerFraction: 0.09,
        notch: .island
    )

    /// An iPad-style frame: thinner bezel, gentler corners, no notch.
    public static let pad = DeviceFrame(
        bezelFraction: 0.035,
        screenCornerFraction: 0.045,
        notch: .none
    )
}
