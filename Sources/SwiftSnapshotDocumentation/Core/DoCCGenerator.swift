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
    /// - Throws: File system errors if the catalog cannot be written
    func generate(at outputPath: String) async throws {
        let fileManager = FileManager.default
        let doccPath = outputPath.hasSuffix(".docc") ? outputPath : "\(outputPath).docc"

        // Create .docc directory structure
        let resourcesPath = "\(doccPath)/Resources"
        let snapshotsPath = "\(resourcesPath)/Snapshots"

        try fileManager.createDirectory(atPath: doccPath, withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: resourcesPath, withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: snapshotsPath, withIntermediateDirectories: true)

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

        // Copy snapshot images from __Snapshots__ to Resources/Snapshots/
        try copySnapshotImages(to: snapshotsPath)

        print("✅ DocC documentation generated at: \(doccPath)")
        print("📊 Screens documented: \(screens.count)")
        print("📸 Total snapshots: \(totalSnapshotCount())")
    }

    /// Generates the main catalog Markdown file.
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

        ## Topics

        ### Screens


        """

        // Add screen references
        for (index, screen) in screens.enumerated() {
            let articleId = String(format: "%02d-%@", index + 1, screen.id)
            content += "- <doc:\(articleId)>\n"
        }

        content += "\n"

        return content
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

    /// Copies snapshot images from __Snapshots__ directory to Resources/Snapshots/.
    private func copySnapshotImages(to destinationPath: String) throws {
        let fileManager = FileManager.default

        var snapshotsSourcePath: String?

        // Use provided path if available
        if let providedPath = snapshotSourcePath {
            if fileManager.fileExists(atPath: providedPath) {
                snapshotsSourcePath = providedPath
            }
        }

        // Otherwise, auto-detect
        if snapshotsSourcePath == nil {
            // Find the __Snapshots__ directory (created by swift-snapshot-testing)
            let currentPath = fileManager.currentDirectoryPath

            // Possible snapshot directory locations
            let possiblePaths = [
                "\(currentPath)/__Snapshots__",
                "\(currentPath)/Tests/__Snapshots__"
            ]

            // Find the first existing __Snapshots__ directory
            for basePath in possiblePaths {
                if fileManager.fileExists(atPath: basePath) {
                    // Look for any test directory inside
                    if let testDirs = try? fileManager.contentsOfDirectory(atPath: basePath) {
                        for testDir in testDirs {
                            let fullPath = "\(basePath)/\(testDir)"
                            var isDir: ObjCBool = false
                            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                                snapshotsSourcePath = fullPath
                                break
                            }
                        }
                    }
                    if snapshotsSourcePath != nil {
                        break
                    }
                }
            }
        }

        guard let sourcePath = snapshotsSourcePath else {
            print("⚠️  No snapshots found")
            if let provided = snapshotSourcePath {
                print("    Provided path: \(provided)")
            }
            print("💡 Make sure to run tests with withSnapshotTesting(record: .all) first")
            return
        }

        // Copy all PNG/JPG files recursively
        var copiedCount = 0

        func copyImagesRecursively(from path: String) throws {
            let contents = try fileManager.contentsOfDirectory(atPath: path)

            for item in contents {
                let itemPath = "\(path)/\(item)"
                var isDir: ObjCBool = false

                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) {
                    if isDir.boolValue {
                        // Recurse into subdirectory
                        try copyImagesRecursively(from: itemPath)
                    } else if item.hasSuffix(".png") || item.hasSuffix(".jpg") {
                        // Strip test name prefix from snapshot filenames
                        // e.g., "testGenerateOnboardingFlowDocumentation.01-welcome-screen-iPhone15Pro-light.png"
                        //    -> "01-welcome-screen-iPhone15Pro-light.png"
                        let cleanedFilename: String
                        if let dotIndex = item.firstIndex(of: "."),
                           item.distance(from: item.startIndex, to: dotIndex) > 10 {
                            // Has prefix like "testSomething."
                            cleanedFilename = String(item[item.index(after: dotIndex)...])
                        } else {
                            cleanedFilename = item
                        }

                        let destPath = "\(destinationPath)/\(cleanedFilename)"

                        if fileManager.fileExists(atPath: destPath) {
                            try fileManager.removeItem(atPath: destPath)
                        }

                        try fileManager.copyItem(atPath: itemPath, toPath: destPath)
                        copiedCount += 1
                    }
                }
            }
        }

        try copyImagesRecursively(from: sourcePath)
        print("📸 Copied \(copiedCount) snapshot images from \(sourcePath)")
    }

    /// Calculates the total number of snapshots.
    private func totalSnapshotCount() -> Int {
        screens.reduce(0) { total, screen in
            total + (screen.devices.count * screen.themes.count)
        }
    }
}
