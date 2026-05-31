//
//  ExportedFeature.swift
//  SwiftSnapshotDocumentation
//

import Foundation

/// The result of exporting one feature into a Flow Explorer bundle.
public struct ExportedFeature: Sendable, Equatable {
    /// Path to the feature's directory inside the explorer bundle.
    public let featurePath: String
    public let screenCount: Int
    public let edgeCount: Int
    public let imageCount: Int
    /// "Source → target" strings for transitions whose target screen was not found.
    public let unresolvedTransitions: [String]

    public init(featurePath: String, screenCount: Int, edgeCount: Int, imageCount: Int, unresolvedTransitions: [String]) {
        self.featurePath = featurePath
        self.screenCount = screenCount
        self.edgeCount = edgeCount
        self.imageCount = imageCount
        self.unresolvedTransitions = unresolvedTransitions
    }
}
