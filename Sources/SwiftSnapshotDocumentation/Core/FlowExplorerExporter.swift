//
//  FlowExplorerExporter.swift
//  SwiftSnapshotDocumentation
//

import Foundation

/// Builds a feature's Flow Explorer data + images and updates the shared manifest.
@MainActor
struct FlowExplorerExporter {
    let flow: DocumentedFlow
    let screens: [DocumentedScreen]
    let snapshotSourcePath: String?
    let configuration: DocumentationConfiguration

    /// Exports this flow into `explorerPath`, writing `<Name>/{feature.json, flows.js, images/}`,
    /// copying the bundle assets if absent, and rebuilding `manifest.js`.
    func export(at explorerPath: String) throws -> ExportedFeature {
        let fileManager = FileManager.default
        guard !screens.isEmpty else { throw DocumentationError.noSnapshotsCopied(sourcePath: explorerPath) }

        let featureDir = "\(explorerPath)/\(flow.name)"
        let imagesDir = "\(featureDir)/images"
        try fileManager.createDirectory(atPath: imagesDir, withIntermediateDirectories: true)

        let (sourcePath, searched) = SnapshotImageCopier.resolveSourceDirectory(provided: snapshotSourcePath, fileManager: fileManager)
        guard let sourcePath else { throw DocumentationError.snapshotsNotFound(searchedPaths: searched) }
        let index = try SnapshotImageCopier.index(at: sourcePath, fileManager: fileManager)

        var imageCount = 0
        var screenData: [FlowData.Screen] = []
        for (i, screen) in screens.enumerated() {
            var variants: [FlowData.Variant] = []
            for device in screen.devices {
                for theme in screen.themes {
                    let cleaned = String(format: "%02d-%@-%@-%@.%@",
                                         i + 1, screen.id, device.name, theme.name,
                                         configuration.imageFormat.rawValue)
                    guard let sourceFile = index[cleaned] else { continue }
                    let frame = configuration.deviceFrames ? device.frame : nil
                    try SnapshotImageCopier.copyImage(from: sourceFile, to: "\(imagesDir)/\(cleaned)", frame: frame)
                    imageCount += 1
                    variants.append(.init(device: device.name, theme: theme.name, image: "images/\(cleaned)"))
                }
            }
            screenData.append(.init(
                id: screen.id, title: screen.title, description: screen.description,
                thumbnail: variants.first?.image ?? "",
                variants: variants,
                callouts: screen.callouts.map { .init(type: $0.type.rawValue, content: $0.content) }
            ))
        }

        guard imageCount > 0 else { throw DocumentationError.noSnapshotsCopied(sourcePath: sourcePath) }

        let resolved = FlowEdgeResolver.resolve(screens: screens)
        let edges = resolved.edges.map { FlowData.Edge(from: $0.from, to: $0.to, label: $0.label) }
        for u in resolved.unresolved { print("⚠️  Flow Explorer: unresolved transition \(u)") }

        let feature = FlowData.Feature(name: flow.name, summary: flow.summary, screens: screenData, edges: edges)
        let json = try FlowData.encoder.encode(feature)
        try json.write(to: URL(fileURLWithPath: "\(featureDir)/feature.json"))
        let jsonString = String(decoding: json, as: UTF8.self)
        let flowsJS = """
        window.FLOW_DATA = window.FLOW_DATA || {};
        window.FLOW_DATA[\(stringLiteral(flow.name))] = \(jsonString);
        """
        try flowsJS.write(toFile: "\(featureDir)/flows.js", atomically: true, encoding: .utf8)

        try copyAssetsIfNeeded(to: explorerPath, fileManager: fileManager)
        try Self.writeManifest(at: explorerPath, fileManager: fileManager)

        print("✅ Flow Explorer feature exported: \(featureDir)")
        return ExportedFeature(featurePath: featureDir, screenCount: screens.count,
                               edgeCount: edges.count, imageCount: imageCount,
                               unresolvedTransitions: resolved.unresolved)
    }

    private func copyAssetsIfNeeded(to explorerPath: String, fileManager: FileManager) throws {
        guard let assets = Bundle.module.url(forResource: "FlowExplorerAssets", withExtension: nil) else { return }
        for item in ["index.html", "app.js", "vendor"] {
            let dest = "\(explorerPath)/\(item)"
            guard !fileManager.fileExists(atPath: dest) else { continue }
            try fileManager.copyItem(at: assets.appendingPathComponent(item), to: URL(fileURLWithPath: dest))
        }
    }

    /// Scans `*/feature.json` and writes `manifest.js` listing every feature.
    static func writeManifest(at explorerPath: String, fileManager: FileManager) throws {
        var entries: [FlowData.ManifestEntry] = []
        let contents = (try? fileManager.contentsOfDirectory(atPath: explorerPath)) ?? []
        for dir in contents.sorted() {
            let marker = "\(explorerPath)/\(dir)/feature.json"
            guard fileManager.fileExists(atPath: marker),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: marker)),
                  let feature = try? JSONDecoder().decode(FlowData.Feature.self, from: data) else { continue }
            entries.append(.init(name: feature.name, dir: dir))
        }
        let manifest = FlowData.Manifest(features: entries)
        let json = try FlowData.encoder.encode(manifest)
        let js = "window.FLOW_MANIFEST = \(String(decoding: json, as: UTF8.self));"
        try js.write(toFile: "\(explorerPath)/manifest.js", atomically: true, encoding: .utf8)
    }

    /// JSON-encodes a string as a JS string literal.
    private func stringLiteral(_ s: String) -> String {
        let data = (try? JSONEncoder().encode(s)) ?? Data("\"\"".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}
