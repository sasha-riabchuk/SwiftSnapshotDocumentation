//
//  ScreenTransition.swift
//  SwiftSnapshotDocumentation
//

import Foundation

/// A directed connection from one ``DocumentedScreen`` to another in a flow.
///
/// Use ``to(_:on:)`` to declare branches and loops, e.g.
/// `.to("Success", on: "valid")` and `.to("Error", on: "invalid")`.
public struct ScreenTransition: Sendable, Equatable {
    /// The target screen's title or id (resolved against screen ids at export time).
    public let target: String

    /// An optional trigger/condition rendered on the edge (e.g. "valid").
    public let label: String?

    /// Creates a screen transition.
    ///
    /// - Parameters:
    ///   - target: The target screen's title or id.
    ///   - label: An optional trigger/condition rendered on the edge.
    public init(target: String, label: String? = nil) {
        self.target = target
        self.label = label
    }

    /// Creates a transition to the screen with the given title/id.
    public static func to(_ target: String, on label: String? = nil) -> ScreenTransition {
        ScreenTransition(target: target, label: label)
    }
}
