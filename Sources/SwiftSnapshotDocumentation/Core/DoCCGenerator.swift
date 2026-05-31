//
//  DoCCGenerator.swift
//  SwiftSnapshotDocumentation
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import Foundation

/// Generates DocC documentation catalogs from documented flows.
///
/// This class handles the creation of DocC `.docc` catalogs, including:
/// - Main catalog file with flow overview
/// - Individual article files for each screen
/// - Resource organization and copying
/// - Navigation and cross-references
///
/// - Note: This class is used internally by ``DocumentedFlow`` and typically
///         doesn't need to be used directly.
///
/// - SeeAlso: ``DocumentedFlow``
@MainActor
final class DoCCGenerator {
    private let flow: DocumentedFlow
    private let screens: [DocumentedScreen]
    private let snapshotSourcePath: String?
    private let configuration: DocumentationConfiguration

    init(
        flow: DocumentedFlow,
        screens: [DocumentedScreen],
        snapshotSourcePath: String?,
        configuration: DocumentationConfiguration
    ) {
        self.flow = flow
        self.screens = screens
        self.snapshotSourcePath = snapshotSourcePath
        self.configuration = configuration
    }

    /// Generates the complete DocC catalog at the specified path.
    ///
    /// - Parameter outputPath: The directory path where the `.docc` catalog should be created
    /// - Returns: A ``GeneratedCatalog`` describing the result (path + counts).
    /// - Throws: ``DocumentationError`` if no snapshots were found/copied, or file
    ///   system errors if the catalog cannot be written.
    @discardableResult
    func generate(at outputPath: String) async throws -> GeneratedCatalog {
        let fileManager = FileManager.default
        let doccPath = outputPath.hasSuffix(".docc") ? outputPath : "\(outputPath).docc"

        // Create .docc directory structure
        let resourcesPath = "\(doccPath)/Resources"
        let snapshotsPath = "\(resourcesPath)/Snapshots"

        try fileManager.createDirectory(atPath: doccPath, withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: resourcesPath, withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: snapshotsPath, withIntermediateDirectories: true)

        // Copy snapshot images first and fail loudly if none are found, so we never
        // emit a catalog whose articles reference images that were never copied.
        let copiedCount = try copySnapshotImages(to: snapshotsPath)

        // Generate main catalog file
        let catalogContent = generateCatalogFile()
        try catalogContent.write(
            toFile: "\(doccPath)/\(flow.name).md",
            atomically: true,
            encoding: .utf8
        )

        // Generate individual screen articles
        for (index, screen) in screens.enumerated() {
            let articleContent = generateArticle(for: screen, index: index + 1)
            let articleFilename = String(format: "%02d-%@.md", index + 1, screen.id)
            try articleContent.write(
                toFile: "\(doccPath)/\(articleFilename)",
                atomically: true,
                encoding: .utf8
            )
        }

        print("✅ DocC documentation generated at: \(doccPath)")
        print("📊 Screens documented: \(screens.count)")
        print("📸 Total snapshots: \(totalSnapshotCount())")
        print("📸 Images copied: \(copiedCount)")

        return GeneratedCatalog(path: doccPath, screenCount: screens.count, imageCount: copiedCount)
    }

    /// Generates the main catalog Markdown file.
    ///
    /// The `@TechnologyRoot` page itself is always written (DocC requires a root),
    /// but its optional sections are config-driven:
    /// - ``DocumentationConfiguration/includeFlowDiagram`` adds a Mermaid diagram of
    ///   the screen sequence after the overview.
    /// - ``DocumentationConfiguration/createIndexPage`` adds the curated
    ///   `Topics → Screens` listing that links to each screen article.
    private func generateCatalogFile() -> String {
        var content = """
        # \(flow.name)

        \(flow.summary)

        @Metadata {
            @PageKind(article)
            @TechnologyRoot
        }

        ## Overview

        \(flow.overview.isEmpty ? "This flow documents the \(flow.name.lowercased()) user experience." : flow.overview)


        """

        if configuration.includeFlowDiagram, !screens.isEmpty {
            content += generateFlowDiagram()
        }

        if configuration.createIndexPage {
            content += """
            ## Topics

            ### Screens


            """

            for (index, screen) in screens.enumerated() {
                let articleId = String(format: "%02d-%@", index + 1, screen.id)
                content += "- <doc:\(articleId)>\n"
            }

            content += "\n"
        }

        return content
    }

    /// Builds a Mermaid flowchart linking the screens in order.
    ///
    /// The flow is the ordered screen sequence, so the diagram connects each screen
    /// to the next. DocC renders fenced `mermaid` blocks as diagrams.
    private func generateFlowDiagram() -> String {
        func node(_ index: Int) -> String {
            let label = screens[index].title.replacingOccurrences(of: "\"", with: "'")
            return "screen\(index)[\"\(label)\"]"
        }

        var lines = ["## Flow", "", "```mermaid", "flowchart TD"]
        if screens.count == 1 {
            lines.append("    \(node(0))")
        } else {
            for index in 0..<(screens.count - 1) {
                lines.append("    \(node(index)) --> \(node(index + 1))")
            }
        }
        lines.append("```")
        lines.append("\n")
        return lines.joined(separator: "\n")
    }

    /// Generates an article for a specific screen.
    private func generateArticle(for screen: DocumentedScreen, index: Int) -> String {
        var content = """
        # \(screen.title)

        \(screen.description)

        ## Overview

        \(screen.discussion ?? "This screen is part of the \(flow.name) flow.")


        """

        // Add callouts
        for callout in screen.callouts {
            content += """
            > \(callout.type.rawValue): \(callout.content)


            """
        }

        for device in screen.devices {
            content += "## \(deviceName(device))\n\n"

            // Light + dark mode side by side
            let hasLight = screen.themes.contains { $0.name == "light" }
            let hasDark = screen.themes.contains { $0.name == "dark" }

            if hasLight && hasDark {
                content += "### Light and Dark Mode\n\n"

                let lightImage = snapshotFilename(index: index, screen: screen, device: device, theme: "light")
                let darkImage = snapshotFilename(index: index, screen: screen, device: device, theme: "dark")

                content += """
                | Light Mode | Dark Mode |
                |-----------|-----------|
                | ![\(deviceName(device)) – Light](\(lightImage)) | ![\(deviceName(device)) – Dark](\(darkImage)) |

                """

            } else {
                // Single theme per device
                for theme in screen.themes {
                    content += "### \(theme.name.capitalized) Mode\n\n"
                    let imageName = snapshotFilename(index: index, screen: screen, device: device, theme: theme.name)
                    content += "![\(deviceName(device)) – \(theme.name.capitalized)](\(imageName))\n\n"
                }
            }
        }

        // Add navigation
        content += "## See Also\n\n"
        if index > 1 {
            let prevArticle = String(format: "%02d-%@", index - 1, screens[index - 2].id)
            content += "- <doc:\(prevArticle)>\n"
        }
        if index < screens.count {
            let nextArticle = String(format: "%02d-%@", index + 1, screens[index].id)
            content += "- <doc:\(nextArticle)>\n"
        }
        content += "- <doc:\(flow.name)>\n"

        return content
    }

    /// Formats a device name for display.
    private func deviceName(_ device: DeviceConfiguration) -> String {
        device.name
            .replacingOccurrences(of: "iPhone", with: "iPhone ")
            .replacingOccurrences(of: "iPad", with: "iPad ")
            .replacingOccurrences(of: "Pro", with: " Pro")
            .replacingOccurrences(of: "SE", with: " SE")
            .replacingOccurrences(of: "Max", with: " Max")
            .replacingOccurrences(of: "  ", with: " ")
    }

    /// Generates the snapshot filename.
    private func snapshotFilename(
        index: Int,
        screen: DocumentedScreen,
        device: DeviceConfiguration,
        theme: String
    ) -> String {
        String(
            format: "%02d-%@-%@-%@.%@",
            index,
            screen.id,
            device.name,
            theme,
            configuration.imageFormat.rawValue
        )
    }

    /// Copies snapshot images from the `__Snapshots__` directory to `Resources/Snapshots/`.
    ///
    /// - Parameter destinationPath: The `Resources/Snapshots` directory to copy into.
    /// - Returns: The number of images copied.
    /// - Throws: ``DocumentationError/snapshotsNotFound(searchedPaths:)`` if no source
    ///   directory exists, or ``DocumentationError/noSnapshotsCopied(sourcePath:)`` if
    ///   the directory exists but holds no images.
    @discardableResult
    private func copySnapshotImages(to destinationPath: String) throws -> Int {
        let fileManager = FileManager.default
        let (sourcePath, searched) = SnapshotImageCopier.resolveSourceDirectory(provided: snapshotSourcePath, fileManager: fileManager)
        guard let sourcePath else { throw DocumentationError.snapshotsNotFound(searchedPaths: searched) }

        let snapshotIndex = try SnapshotImageCopier.index(at: sourcePath, fileManager: fileManager)
        var copied = 0
        // Copy order is irrelevant — DocC resolves images by filename.
        for (cleanedName, sourceFilePath) in snapshotIndex {
            let device = device(forImageName: cleanedName)
            let subdir: String
            if configuration.organizeByDevice, let device {
                subdir = "/\(device.name)"
            } else {
                subdir = ""
            }
            let destPath = "\(destinationPath)\(subdir)/\(cleanedName)"
            let frame = (configuration.deviceFrames ? device?.frame : nil)
            try SnapshotImageCopier.copyImage(from: sourceFilePath, to: destPath, frame: frame)
            copied += 1
        }
        guard copied > 0 else { throw DocumentationError.noSnapshotsCopied(sourcePath: sourcePath) }
        print("📸 Copied \(copied) snapshot images from \(sourcePath)")
        return copied
    }

    /// Finds the device a cleaned snapshot filename belongs to.
    ///
    /// Filenames look like `NN-<screen-id>-<deviceName>-<theme>.ext`; the screen id
    /// may itself contain hyphens, so rather than split, we match each known device
    /// name anchored by surrounding hyphens (`-iPhone15Pro-`). Anchoring keeps
    /// `iPhone15Pro` from matching `iPhone15ProMax`.
    private func device(forImageName filename: String) -> DeviceConfiguration? {
        for device in knownDevices where filename.contains("-\(device.name)-") {
            return device
        }
        return nil
    }

    /// The distinct devices referenced by this flow's screens.
    private var knownDevices: [DeviceConfiguration] {
        var seen = Set<String>()
        var result: [DeviceConfiguration] = []
        for device in screens.flatMap(\.devices) where seen.insert(device.name).inserted {
            result.append(device)
        }
        return result
    }

    /// Calculates the total number of snapshots.
    private func totalSnapshotCount() -> Int {
        screens.reduce(0) { total, screen in
            total + (screen.devices.count * screen.themes.count)
        }
    }
}
