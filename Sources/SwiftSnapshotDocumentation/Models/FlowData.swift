//
//  FlowData.swift
//  SwiftSnapshotDocumentation
//

import Foundation

/// Codable shapes for the neutral data contract written to `flows.js` / `manifest.js`.
enum FlowData {
    struct Feature: Codable, Equatable {
        let name: String
        let summary: String
        let screens: [Screen]
        let edges: [Edge]
    }
    struct Screen: Codable, Equatable {
        let id: String
        let title: String
        let description: String
        let thumbnail: String
        let variants: [Variant]
        let callouts: [Callout]
    }
    struct Variant: Codable, Equatable {
        let device: String
        let theme: String
        let image: String
    }
    struct Callout: Codable, Equatable {
        let type: String
        let content: String
    }
    struct Edge: Codable, Equatable {
        let from: String
        let to: String
        let label: String?
    }
    struct ManifestEntry: Codable, Equatable {
        let name: String
        let dir: String
    }
    struct Manifest: Codable, Equatable {
        let features: [ManifestEntry]
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
