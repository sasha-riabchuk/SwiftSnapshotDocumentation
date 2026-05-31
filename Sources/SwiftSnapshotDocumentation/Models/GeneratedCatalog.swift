//
//  GeneratedCatalog.swift
//  SwiftSnapshotDocumentation
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import Foundation

/// The result of generating a DocC catalog.
///
/// Returned by ``DocumentedFlow/generateDocumentation(outputPath:snapshotSourcePath:configuration:)``
/// so callers (and tooling) can confirm success programmatically instead of parsing
/// console output — e.g. assert `imageCount > 0` or read `path` to open the catalog.
public struct GeneratedCatalog: Sendable, Equatable {
    /// The absolute or relative path to the generated `.docc` catalog directory.
    public let path: String

    /// The number of screens documented (one article each).
    public let screenCount: Int

    /// The number of snapshot images copied into the catalog.
    public let imageCount: Int

    public init(path: String, screenCount: Int, imageCount: Int) {
        self.path = path
        self.screenCount = screenCount
        self.imageCount = imageCount
    }
}
