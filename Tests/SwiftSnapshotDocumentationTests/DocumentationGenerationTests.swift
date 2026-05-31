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
import CoreGraphics
import ImageIO
import SnapshotTesting
@testable import SwiftSnapshotDocumentation

// MARK: - Off-iOS "no snapshots" maps to a clear captureUnavailable error

@Test func noSnapshotsMapsToCaptureUnavailableWhenCaptureUnsupported() {
    // Capture unsupported: "no snapshots" failures become the precise platform error.
    #expect(DocumentedFlow.mappedGenerationError(.noSnapshotsCopied(sourcePath: "/x"), captureSupported: false) == .captureUnavailable)
    #expect(DocumentedFlow.mappedGenerationError(.snapshotsNotFound(searchedPaths: ["/x"]), captureSupported: false) == .captureUnavailable)
    // Unrelated errors pass through unchanged.
    #expect(DocumentedFlow.mappedGenerationError(.imageProcessingFailed(path: "/x"), captureSupported: false) == .imageProcessingFailed(path: "/x"))
    // Capture supported (iOS): nothing is remapped — the original error stands.
    #expect(DocumentedFlow.mappedGenerationError(.noSnapshotsCopied(sourcePath: "/x"), captureSupported: true) == .noSnapshotsCopied(sourcePath: "/x"))
}

// MARK: - Record mode maps to swift-snapshot-testing

@Test func recordModeMapsToSnapshotTestingRecord() {
    #expect(SnapshotRecordMode.record.configuration == .all)
    #expect(SnapshotRecordMode.recordMissing.configuration == .missing)
    #expect(SnapshotRecordMode.verify.configuration == .never)
}

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
        devices: [makeDevice("iPhone15Pro")],
        themes: [.light, .dark]
    )
}

private func screen(_ title: String) -> DocumentedScreen {
    DocumentedScreen(
        title: title,
        description: "\(title) description",
        devices: [makeDevice("iPhone15Pro")],
        themes: [.light]
    )
}

@MainActor
private func makeGenerator(
    source: String?,
    screens: [DocumentedScreen],
    configuration: DocumentationConfiguration = .init(deviceFrames: false)
) -> DoCCGenerator {
    DoCCGenerator(
        flow: DocumentedFlow(name: "MyFlow", summary: "A flow"),
        screens: screens,
        snapshotSourcePath: source,
        configuration: configuration
    )
}

/// Writes a dummy image file (content is irrelevant; copying is byte-agnostic).
private func writeDummyImage(named name: String, in directory: URL) throws {
    try Data([0x89, 0x50, 0x4E, 0x47]).write(to: directory.appendingPathComponent(name))
}

// MARK: - CoreGraphics image helpers (for device-frame tests)

/// Builds an opaque image whose top half is red and bottom half is blue, so tests
/// can detect both bezel placement and vertical orientation.
private func makeTopRedBottomBlueImage(width: Int, height: Int) -> CGImage {
    var data = [UInt8](repeating: 0, count: width * height * 4)
    data.withUnsafeMutableBytes { raw in
        let ctx = CGContext(
            data: raw.baseAddress,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.translateBy(x: 0, y: CGFloat(height))  // top-left coordinate system
        ctx.scaleBy(x: 1, y: -1)
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height) / 2))
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: CGFloat(height) / 2, width: CGFloat(width), height: CGFloat(height) / 2))
    }
    let provider = CGDataProvider(data: Data(data) as CFData)!
    return CGImage(
        width: width, height: height,
        bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
    )!
}

private func writePNG(_ image: CGImage, to url: URL) throws {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    #expect(CGImageDestinationFinalize(dest))
}

private func loadPNG(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

/// A top=red / bottom=blue image created the way production snapshots arrive: via
/// `CGContext.makeImage()` and round-tripped through a PNG (so its orientation matches
/// an ImageIO-loaded file). Use this for orientation/notch assertions —
/// `makeTopRedBottomBlueImage` builds a buffer-backed CGImage whose orientation is
/// inverted relative to real PNGs, which previously masked a notch-placement bug.
private func realTopRedBottomBlueImage(width: Int, height: Int) -> CGImage {
    let ctx = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    // Bottom-up context: high y is the visual top.
    ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: CGFloat(height) / 2, width: CGFloat(width), height: CGFloat(height) / 2))
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height) / 2))
    let image = ctx.makeImage()!
    // Round-trip through PNG entirely in memory so the result has ImageIO orientation.
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest),
          let src = CGImageSourceCreateWithData(data, nil),
          let reloaded = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return image }
    return reloaded
}

/// Reads pixels of `image` in a top-left coordinate system, RGBA premultiplied.
private func pixels(of image: CGImage) -> (width: Int, height: Int, data: [UInt8]) {
    let w = image.width, h = image.height
    var data = [UInt8](repeating: 0, count: w * h * 4)
    data.withUnsafeMutableBytes { raw in
        let ctx = CGContext(
            data: raw.baseAddress, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.translateBy(x: 0, y: CGFloat(h))  // make buffer row 0 = top of image
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
    }
    return (w, h, data)
}

private func pixel(_ p: (width: Int, height: Int, data: [UInt8]), _ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    let i = (y * p.width + x) * 4
    return (p.data[i], p.data[i + 1], p.data[i + 2], p.data[i + 3])
}

// MARK: - deviceFrames: renderer composites a bezel around the screenshot

private func channelsClose(_ a: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ b: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
    func near(_ x: UInt8, _ y: UInt8) -> Bool { abs(Int(x) - Int(y)) < 40 }
    return near(a.r, b.r) && near(a.g, b.g) && near(a.b, b.b)
}

@Test func renderFramedImageAddsBezelPreservesOrientationAndDrawsNotch() {
    let input = realTopRedBottomBlueImage(width: 100, height: 200)  // real-PNG orientation

    let framed = DeviceFrameRenderer.renderFramedImage(input, frame: .phone)
    #expect(framed != nil)
    guard let framed else { return }

    // bezel = round(0.04 * min(100,200)) = 4, added on every edge.
    #expect(framed.width == 108)
    #expect(framed.height == 208)

    let p = pixels(of: framed)

    // NOTE: `pixels(of:)` samples y from the image's BOTTOM edge, so the screenshot's
    // TOP (red) appears at HIGH y and its bottom (blue) at low y. The Dynamic Island,
    // which must sit at the device's top, therefore appears at high y.

    // Bezel (left edge, mid-height) is black.
    let bezel = pixel(p, 1, 104)
    #expect(bezel.r < 40 && bezel.g < 40 && bezel.b < 40 && bezel.a > 200)

    // Orientation preserved: red = screenshot top (high y), blue = bottom (low y).
    let screenTop = pixel(p, 20, 180)
    #expect(screenTop.r > 200 && screenTop.b < 60)
    let screenBottom = pixel(p, 20, 30)
    #expect(screenBottom.b > 200 && screenBottom.r < 60)

    // Dynamic Island is over the screenshot's TOP (high y, same side as red), NOT the
    // bottom — the regression guard for "notch on the wrong end".
    let notchAtTop = pixel(p, 54, 200)
    #expect(notchAtTop.r < 40 && notchAtTop.g < 40 && notchAtTop.b < 40 && notchAtTop.a > 200)
    let screenBottomCenter = pixel(p, 54, 8)
    #expect(!(screenBottomCenter.r < 40 && screenBottomCenter.g < 40 && screenBottomCenter.b < 40))
}

@Test func renderFramedImageWithoutNotchLeavesTopCenterVisible() {
    let input = realTopRedBottomBlueImage(width: 100, height: 200)

    let framed = DeviceFrameRenderer.renderFramedImage(input, frame: .pad)
    #expect(framed != nil)
    guard let framed else { return }

    // With no notch, the screenshot's top-center (high y, red) shows through — no black pill.
    let topCenter = pixel(pixels(of: framed), 54, 196)
    #expect(topCenter.r > 200 && topCenter.b < 60)
}

// MARK: - deviceFrames + organizeByDevice wired through generation

@MainActor
@Test func generateFramesImagesWhenDeviceFramesEnabled() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appendingPathComponent("__Snapshots__/MyTests", isDirectory: true)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    let input = makeTopRedBottomBlueImage(width: 100, height: 200)
    try writePNG(input, to: source.appendingPathComponent("testX.01-welcome-iPhone15Pro-light.png"))

    let generator = makeGenerator(
        source: source.path,
        screens: [welcomeScreen()],
        configuration: .init(deviceFrames: true, organizeByDevice: false)
    )
    try await generator.generate(at: root.appendingPathComponent("MyFlow").path)

    let out = root.appendingPathComponent("MyFlow.docc/Resources/Snapshots/01-welcome-iPhone15Pro-light.png")
    #expect(FileManager.default.fileExists(atPath: out.path))
    // The framed image is larger than the 100x200 source (bezel added on every side).
    let framed = loadPNG(out)
    #expect(framed?.width == 108)
    #expect(framed?.height == 208)
}

@MainActor
@Test func generateGroupsImagesByDeviceWhenEnabled() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appendingPathComponent("__Snapshots__/MyTests", isDirectory: true)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try writeDummyImage(named: "testX.01-welcome-iPhone15Pro-light.png", in: source)

    let generator = makeGenerator(
        source: source.path,
        screens: [welcomeScreen()],
        configuration: .init(deviceFrames: false, organizeByDevice: true)
    )
    try await generator.generate(at: root.appendingPathComponent("MyFlow").path)

    let snapshots = root.appendingPathComponent("MyFlow.docc/Resources/Snapshots", isDirectory: true)
    // Grouped into a per-device subfolder, not placed at the root.
    #expect(FileManager.default.fileExists(atPath: snapshots.appendingPathComponent("iPhone15Pro/01-welcome-iPhone15Pro-light.png").path))
    #expect(!FileManager.default.fileExists(atPath: snapshots.appendingPathComponent("01-welcome-iPhone15Pro-light.png").path))
}

// MARK: - createIndexPage + includeFlowDiagram catalog sections

@MainActor
@Test func catalogIncludesTopicsAndFlowDiagramWhenEnabled() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appendingPathComponent("__Snapshots__/MyTests", isDirectory: true)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try writeDummyImage(named: "testX.01-welcome-screen-iPhone15Pro-light.png", in: source)

    let generator = makeGenerator(
        source: source.path,
        screens: [screen("Welcome Screen"), screen("Login Screen")],
        configuration: .init(deviceFrames: false, createIndexPage: true, includeFlowDiagram: true)
    )
    try await generator.generate(at: root.appendingPathComponent("MyFlow").path)

    let catalog = try String(
        contentsOf: root.appendingPathComponent("MyFlow.docc/MyFlow.md"),
        encoding: .utf8
    )

    // Index page: curated Topics listing linking each screen article.
    #expect(catalog.contains("## Topics"))
    #expect(catalog.contains("<doc:01-welcome-screen>"))
    #expect(catalog.contains("<doc:02-login-screen>"))

    // Flow diagram: a Mermaid flowchart connecting the screens in order.
    #expect(catalog.contains("```mermaid"))
    #expect(catalog.contains("flowchart TD"))
    #expect(catalog.contains("screen0[\"Welcome Screen\"] --> screen1[\"Login Screen\"]"))
}

@MainActor
@Test func catalogOmitsTopicsAndFlowDiagramWhenDisabled() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appendingPathComponent("__Snapshots__/MyTests", isDirectory: true)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try writeDummyImage(named: "testX.01-welcome-screen-iPhone15Pro-light.png", in: source)

    let generator = makeGenerator(
        source: source.path,
        screens: [screen("Welcome Screen"), screen("Login Screen")],
        configuration: .init(deviceFrames: false, createIndexPage: false, includeFlowDiagram: false)
    )
    try await generator.generate(at: root.appendingPathComponent("MyFlow").path)

    let catalog = try String(
        contentsOf: root.appendingPathComponent("MyFlow.docc/MyFlow.md"),
        encoding: .utf8
    )

    // Root page is still written (DocC requires it) but the optional sections are gone.
    #expect(catalog.contains("@TechnologyRoot"))
    #expect(!catalog.contains("## Topics"))
    #expect(!catalog.contains("```mermaid"))
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
    let result = try await generator.generate(at: outputPath)

    // The returned result lets callers verify success without scraping stdout.
    #expect(result.path.hasSuffix("MyFlow.docc"))
    #expect(result.screenCount == 1)
    #expect(result.imageCount == 2)

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
