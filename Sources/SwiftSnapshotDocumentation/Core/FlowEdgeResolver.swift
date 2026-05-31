//
//  FlowEdgeResolver.swift
//  SwiftSnapshotDocumentation
//

import Foundation

/// Resolves a flow's screens into directed edges between screen ids.
enum FlowEdgeResolver {
    struct Edge: Equatable {
        let from: String
        let to: String
        let label: String?
    }

    struct Result: Equatable {
        let edges: [Edge]
        /// Human-readable "Source → target" strings for transitions whose target
        /// did not match any screen.
        let unresolved: [String]
    }

    /// - If no screen declares any transition, edges follow add order (A→B→C).
    /// - If any transition exists, only explicit transitions become edges.
    /// - Transition targets match a screen by `id` or by sanitized title.
    static func resolve(screens: [DocumentedScreen]) -> Result {
        let idByKey = screenLookup(screens)
        let hasExplicit = screens.contains { !$0.transitions.isEmpty }

        guard hasExplicit else {
            var edges: [Edge] = []
            for pair in zip(screens, screens.dropFirst()) {
                edges.append(Edge(from: pair.0.id, to: pair.1.id, label: nil))
            }
            return Result(edges: edges, unresolved: [])
        }

        var edges: [Edge] = []
        var unresolved: [String] = []
        for screen in screens {
            for transition in screen.transitions {
                if let targetId = idByKey[transition.target.lowercased()]
                    ?? idByKey[transition.target.sanitizedForFilename()] {
                    edges.append(Edge(from: screen.id, to: targetId, label: transition.label))
                } else {
                    unresolved.append("\(screen.title) → \(transition.target)")
                }
            }
        }
        return Result(edges: edges, unresolved: unresolved)
    }

    /// Maps both the lowercased title and the id to the screen's id, for flexible
    /// target matching.
    private static func screenLookup(_ screens: [DocumentedScreen]) -> [String: String] {
        var map: [String: String] = [:]
        for screen in screens {
            map[screen.id] = screen.id
            map[screen.title.lowercased()] = screen.id
        }
        return map
    }
}
