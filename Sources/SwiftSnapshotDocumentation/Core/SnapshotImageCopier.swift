//
//  SnapshotImageCopier.swift
//  SwiftSnapshotDocumentation
//

import Foundation

/// Locates and copies snapshot images, optionally compositing a device frame.
/// Shared by ``DoCCGenerator`` and ``FlowExplorerExporter``.
enum SnapshotImageCopier {
    /// Removes the leading `<testName>.` prefix swift-snapshot-testing prepends,
    /// anchored on the `NN-` identifier so it works for any test-name length.
    static func strippedSnapshotName(_ filename: String) -> String {
        guard let match = filename.range(of: #"^.*?\.(?=\d{2}-)"#, options: .regularExpression) else {
            return filename
        }
        return String(filename[match.upperBound...])
    }

    /// Resolution order: an explicitly provided path, then a best-effort scan
    /// relative to the working directory. Returns the resolved path (or nil) and
    /// every path searched.
    static func resolveSourceDirectory(provided: String?, fileManager: FileManager) -> (path: String?, searched: [String]) {
        var searched: [String] = []
        if let provided {
            searched.append(provided)
            if fileManager.fileExists(atPath: provided) { return (provided, searched) }
        }
        let cwd = fileManager.currentDirectoryPath
        for base in ["\(cwd)/__Snapshots__", "\(cwd)/Tests/__Snapshots__"] {
            searched.append(base)
            guard fileManager.fileExists(atPath: base),
                  let entries = try? fileManager.contentsOfDirectory(atPath: base) else { continue }
            for entry in entries {
                let full = "\(base)/\(entry)"
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue {
                    return (full, searched)
                }
            }
        }
        return (nil, searched)
    }

    /// Builds `[cleanedFilename: sourcePath]` by recursively scanning `directory`
    /// for `.png`/`.jpg` files.
    static func index(at directory: String, fileManager: FileManager) throws -> [String: String] {
        var result: [String: String] = [:]
        func walk(_ path: String) throws {
            for item in try fileManager.contentsOfDirectory(atPath: path) {
                let itemPath = "\(path)/\(item)"
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) else { continue }
                if isDir.boolValue {
                    try walk(itemPath)
                } else if item.hasSuffix(".png") || item.hasSuffix(".jpg") {
                    result[strippedSnapshotName(item)] = itemPath
                }
            }
        }
        try walk(directory)
        return result
    }

    /// Copies one image, compositing `frame` when non-nil and the file is a PNG.
    static func copyImage(from sourcePath: String, to destPath: String, frame: DeviceFrame?) throws {
        let fileManager = FileManager.default
        let destDir = (destPath as NSString).deletingLastPathComponent
        try fileManager.createDirectory(atPath: destDir, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destPath) { try fileManager.removeItem(atPath: destPath) }
        if let frame, sourcePath.hasSuffix(".png") {
            try DeviceFrameRenderer.writeFramedPNG(from: sourcePath, to: destPath, frame: frame)
        } else {
            try fileManager.copyItem(atPath: sourcePath, toPath: destPath)
        }
    }
}
