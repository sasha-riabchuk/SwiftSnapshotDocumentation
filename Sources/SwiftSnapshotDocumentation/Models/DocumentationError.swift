//
//  DocumentationError.swift
//  SwiftSnapshotDocumentation
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import Foundation

/// Errors thrown while generating a DocC documentation catalog.
public enum DocumentationError: Error, CustomStringConvertible, Equatable {
    /// No `__Snapshots__` directory could be located.
    ///
    /// The associated value lists every path that was searched, to aid debugging.
    case snapshotsNotFound(searchedPaths: [String])

    /// A snapshots directory was found, but it contained no `.png`/`.jpg` images
    /// to copy into the catalog.
    ///
    /// This usually means the documentation test was run without first recording
    /// snapshots (i.e. on a non-iOS platform, or with `isRecording = false` on a
    /// fresh checkout).
    case noSnapshotsCopied(sourcePath: String)

    /// An image could not be decoded or re-encoded while compositing a device frame.
    case imageProcessingFailed(path: String)

    /// Generation found no snapshots, and snapshot capture is unavailable on this
    /// platform — i.e. the test is running somewhere other than iOS and there were
    /// no pre-recorded snapshots to fall back on.
    case captureUnavailable

    public var description: String {
        switch self {
        case let .snapshotsNotFound(searchedPaths):
            return """
            No __Snapshots__ directory found. Searched:
            \(searchedPaths.map { "  - \($0)" }.joined(separator: "\n"))
            Run the documentation test on an iOS simulator with isRecording = true first.
            """
        case let .noSnapshotsCopied(sourcePath):
            return """
            Snapshots directory '\(sourcePath)' contained no images to copy.
            Snapshot capture is iOS-only — run the test on an iOS simulator with \
            isRecording = true so screenshots are produced before generating docs.
            """
        case let .imageProcessingFailed(path):
            return "Failed to process image while compositing a device frame: \(path)"
        case .captureUnavailable:
            return """
            Snapshot capture is only available on iOS, and no pre-recorded snapshots \
            were found. Run your documentation test on an iOS simulator, e.g.:
              xcodebuild test -scheme <Scheme> \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
            (Generating from already-committed snapshots does work on macOS.)
            """
        }
    }
}
