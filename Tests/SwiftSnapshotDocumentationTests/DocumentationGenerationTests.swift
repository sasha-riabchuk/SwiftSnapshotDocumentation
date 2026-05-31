//
//  DocumentationGenerationTests.swift
//  SwiftSnapshotDocumentation
//
//  Verifies the snapshot -> DocC catalog pipeline: that images are located
//  deterministically, copied into the catalog, and that generation fails loudly
//  when no snapshots are available.
//
//  These tests drive `DoCCGenerator` directly (rather than `DocumentedFlow.addScreen`,
//  which performs real iOS snapshot capture) so they exercise only the generation
//  half of the pipeline with controlled, pre-supplied snapshot images.
//

import Testing
import Foundation
import SwiftUI
@testable import SwiftSnapshotDocumentation

// MARK: - Helpers

private func makeTempDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("ssd-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeDevice(_ name: String) -> DeviceConfiguration {
    #if os(iOS)
    return DeviceConfiguration(name: name, viewImageConfig: .iPhone13Pro)
    #else
    return DeviceConfiguration(name: name, viewImageConfig: 0)
    #endif
}

private func welcomeScreen() -> DocumentedScreen {
    DocumentedScreen(
        title: "Welcome",
        description: "Landing screen",
        viewBuilder: { Text("Welcome") },
        devices: [makeDevice("iPhone15Pro")],
        themes: [.light, .dark]
    )
}

@MainActor
private func makeGenerator(source: String?, screens: [DocumentedScreen]) -> DoCCGenerator {
    DoCCGenerator(
        flow: DocumentedFlow(name: "MyFlow", summary: "A flow"),
        screens: screens,
        snapshotSourcePath: source,
        configuration: .init()
    )
}

/// Writes a dummy image file (content is irrelevant; copying is byte-agnostic).
private func writeDummyImage(named name: String, in directory: URL) throws {
    try Data([0x89, 0x50, 0x4E, 0x47]).write(to: directory.appendingPathComponent(name))
}

// MARK: - Tolerances map to swift-snapshot-testing precision values

@Test func tolerancesMapToSnapshotPrecision() {
    let config = DocumentationConfiguration(perPixelTolerance: 0.01, overallTolerance: 0.05)
    // precision = 1 - overallTolerance, perceptualPrecision = 1 - perPixelTolerance
    #expect(abs(config.snapshotPrecision - 0.95) < 1e-6)
    #expect(abs(config.snapshotPerceptualPrecision - 0.99) < 1e-6)
}

@Test func toleranceMappingClampsToUnitInterval() {
    let tooLoose = DocumentationConfiguration(perPixelTolerance: 2, overallTolerance: 2)
    #expect(tooLoose.snapshotPrecision == 0)
    #expect(tooLoose.snapshotPerceptualPrecision == 0)

    let negative = DocumentationConfiguration(perPixelTolerance: -1, overallTolerance: -1)
    #expect(negative.snapshotPrecision == 1)
    #expect(negative.snapshotPerceptualPrecision == 1)
}

// MARK: - Fix #1: deterministic snapshot directory derivation

@Test func snapshotDirectoryMatchesSnapshotTestingLayout() {
    let dir = DocumentedFlow.snapshotDirectory(forFile: "/a/b/Tests/MyFeatureTests/MyTests.swift")
    #expect(dir == "/a/b/Tests/MyFeatureTests/__Snapshots__/MyTests")
}

// MARK: - Fix #1: images are copied into the catalog with the test-name prefix stripped

@MainActor
@Test func generateCopiesSnapshotsAndStripsTestNamePrefix() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }

    // Simulate what swift-snapshot-testing wrote: "<testName>.<identifier>.png".
    let source = root.appendingPathComponent("__Snapshots__/MyTests", isDirectory: true)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try writeDummyImage(named: "testSomething.01-welcome-iPhone15Pro-light.png", in: source)
    try writeDummyImage(named: "testSomething.01-welcome-iPhone15Pro-dark.png", in: source)

    let generator = makeGenerator(source: source.path, screens: [welcomeScreen()])
    let outputPath = root.appendingPathComponent("MyFlow").path
    try await generator.generate(at: outputPath)

    let snapshots = root.appendingPathComponent("MyFlow.docc/Resources/Snapshots", isDirectory: true)
    let light = snapshots.appendingPathComponent("01-welcome-iPhone15Pro-light.png")
    let dark = snapshots.appendingPathComponent("01-welcome-iPhone15Pro-dark.png")

    // The test-name prefix must be stripped so copied names match the article links.
    #expect(FileManager.default.fileExists(atPath: light.path))
    #expect(FileManager.default.fileExists(atPath: dark.path))

    // The generated article must reference exactly those copied filenames.
    let article = try String(
        contentsOf: root.appendingPathComponent("MyFlow.docc/01-welcome.md"),
        encoding: .utf8
    )
    #expect(article.contains("01-welcome-iPhone15Pro-light.png"))
    #expect(article.contains("01-welcome-iPhone15Pro-dark.png"))
}

// MARK: - Fix #2: generation fails loudly instead of producing a broken catalog

@MainActor
@Test func generateThrowsWhenSnapshotsDirectoryIsEmpty() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }

    let emptySource = root.appendingPathComponent("__Snapshots__/Empty", isDirectory: true)
    try FileManager.default.createDirectory(at: emptySource, withIntermediateDirectories: true)

    let generator = makeGenerator(source: emptySource.path, screens: [welcomeScreen()])

    await #expect(throws: DocumentationError.noSnapshotsCopied(sourcePath: emptySource.path)) {
        try await generator.generate(at: root.appendingPathComponent("MyFlow").path)
    }
}

@MainActor
@Test func generateThrowsWhenSnapshotsDirectoryIsMissing() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }

    let missing = root.appendingPathComponent("does-not-exist").path
    let generator = makeGenerator(source: missing, screens: [welcomeScreen()])

    await #expect(throws: DocumentationError.self) {
        try await generator.generate(at: root.appendingPathComponent("MyFlow").path)
    }
}
