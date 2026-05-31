import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import SwiftSnapshotDocumentation

/// Writes a small valid PNG so thumbnail/data-URI generation has a real image to decode.
private func writeRealPNG(to url: URL, width: Int = 60, height: Int = 120) {
    let ctx = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
    let image = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    _ = CGImageDestinationFinalize(dest)
}

@MainActor
@Test func exporterEmbedsThumbnailAsDataURI() throws {
    let root = try fxTempDir(); defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("__Snapshots__/MyTests", isDirectory: true)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    writeRealPNG(to: source.appendingPathComponent("t.01-welcome-iPhone15Pro-light.png"))

    let flow = DocumentedFlow(name: "Onboarding", summary: "s")
    let screens = [DocumentedScreen(title: "Welcome", description: "d", devices: [fxDevice("iPhone15Pro")], themes: [.light])]
    let exporter = FlowExplorerExporter(flow: flow, screens: screens,
                                        snapshotSourcePath: source.path,
                                        configuration: .init(deviceFrames: false))
    _ = try exporter.export(at: root.appendingPathComponent("FlowExplorer").path)

    let json = try Data(contentsOf: root.appendingPathComponent("FlowExplorer/Onboarding/feature.json"))
    let feature = try JSONDecoder().decode(FlowData.Feature.self, from: json)
    // Each variant carries an embedded data-URI thumbnail (so the toolbar can re-skin
    // nodes and they render in canvas over file://).
    let variant = feature.screens.first?.variants.first
    #expect(variant?.thumbnail.hasPrefix("data:image/") == true)
    #expect((variant?.width ?? 0) > 0 && (variant?.height ?? 0) > 0)
    // Variant panel images remain plain file references.
    #expect(variant?.image == "images/01-welcome-iPhone15Pro-light.png")
    // The screen's default thumbnail is the first variant's data URI.
    #expect(feature.screens.first?.thumbnail.hasPrefix("data:image/") == true)
}

@Test func screenTransitionFactorySetsTargetAndLabel() {
    let t1 = ScreenTransition.to("Success", on: "valid")
    #expect(t1.target == "Success")
    #expect(t1.label == "valid")

    let t2 = ScreenTransition.to("Home")
    #expect(t2.target == "Home")
    #expect(t2.label == nil)
}

@Test func documentedScreenStoresTransitions() {
    let screen = DocumentedScreen(
        title: "Login",
        description: "Auth",
        devices: [],
        themes: [],
        transitions: [.to("Success", on: "valid"), .to("Error", on: "invalid")]
    )
    #expect(screen.transitions.count == 2)
    #expect(screen.transitions.first?.target == "Success")
    #expect(screen.transitions.last?.target == "Error")
}

private func screenStub(_ title: String, _ transitions: [ScreenTransition] = []) -> DocumentedScreen {
    DocumentedScreen(title: title, description: "d", devices: [], themes: [], transitions: transitions)
}

@Test func edgeResolverFallsBackToLinearWhenNoTransitions() {
    let screens = [screenStub("Welcome"), screenStub("Login"), screenStub("Profile")]
    let result = FlowEdgeResolver.resolve(screens: screens)
    #expect(result.edges == [
        .init(from: "welcome", to: "login", label: nil),
        .init(from: "login", to: "profile", label: nil),
    ])
    #expect(result.unresolved.isEmpty)
}

@Test func edgeResolverUsesExplicitTransitionsOnly() {
    let screens = [
        screenStub("Login", [.to("Success", on: "valid"), .to("Error", on: "invalid")]),
        screenStub("Success"),
        screenStub("Error"),
    ]
    let result = FlowEdgeResolver.resolve(screens: screens)
    #expect(result.edges == [
        .init(from: "login", to: "success", label: "valid"),
        .init(from: "login", to: "error", label: "invalid"),
    ])
    #expect(result.unresolved.isEmpty)
}

@Test func edgeResolverReportsUnresolvedTargetsAndSkipsThem() {
    let screens = [screenStub("Login", [.to("Nowhere")]), screenStub("Home")]
    let result = FlowEdgeResolver.resolve(screens: screens)
    #expect(result.edges.isEmpty)
    #expect(result.unresolved == ["Login → Nowhere"])
}

@Test func edgeResolverResolvesTargetBySanitizedTitle() {
    let screens = [
        DocumentedScreen(title: "Home", description: "d", devices: [], themes: [], transitions: [.to("sign-up")]),
        DocumentedScreen(id: "custom", title: "Sign Up", description: "d", devices: [], themes: []),
    ]
    let result = FlowEdgeResolver.resolve(screens: screens)
    #expect(result.edges == [.init(from: "home", to: "custom", label: nil)])
    #expect(result.unresolved.isEmpty)
}

@Test func exportedFeatureStoresCounts() {
    let f = ExportedFeature(featurePath: "/x/Onboarding", screenCount: 3, edgeCount: 2, imageCount: 6, unresolvedTransitions: [])
    #expect(f.featurePath == "/x/Onboarding")
    #expect(f.screenCount == 3)
    #expect(f.edgeCount == 2)
    #expect(f.imageCount == 6)
    #expect(f.unresolvedTransitions.isEmpty)
}

private func fxTempDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("ssd-fx-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func snapshotImageCopierStripsPrefixAndIndexes() throws {
    let dir = try fxTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    try Data([0x89]).write(to: dir.appendingPathComponent("testFoo.01-welcome-iPhone15Pro-light.png"))
    let index = try SnapshotImageCopier.index(at: dir.path, fileManager: .default)
    #expect(index["01-welcome-iPhone15Pro-light.png"] != nil)
}

@Test func snapshotImageCopierCopiesPlainImage() throws {
    let dir = try fxTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let src = dir.appendingPathComponent("a.png"); try Data([0x89, 0x50]).write(to: src)
    let dest = dir.appendingPathComponent("out/a.png")
    try SnapshotImageCopier.copyImage(from: src.path, to: dest.path, frame: nil)
    #expect(FileManager.default.fileExists(atPath: dest.path))
    #expect((try? Data(contentsOf: dest)) == Data([0x89, 0x50]))
}

@Test func flowDataEncodesToStableJSON() throws {
    let feature = FlowData.Feature(
        name: "Onboarding", summary: "s",
        screens: [.init(id: "welcome", title: "Welcome", description: "d",
                        thumbnail: "images/01-welcome-iPhone15Pro-light.png",
                        variants: [.init(device: "iPhone15Pro", theme: "light", image: "images/01-welcome-iPhone15Pro-light.png", thumbnail: "data:image/png;base64,AA", width: 100, height: 200)],
                        callouts: [.init(type: "tip", content: "hi")])],
        edges: [.init(from: "welcome", to: "login", label: "next")])
    let data = try FlowData.encoder.encode(feature)
    let decoded = try JSONDecoder().decode(FlowData.Feature.self, from: data)
    #expect(decoded == feature)
    #expect(decoded.screens.first?.thumbnail == "images/01-welcome-iPhone15Pro-light.png")
}

private func fxDevice(_ name: String) -> DeviceConfiguration {
    #if os(iOS)
    return DeviceConfiguration(name: name, viewImageConfig: .iPhone13Pro)
    #else
    return DeviceConfiguration(name: name, viewImageConfig: 0)
    #endif
}

@MainActor
@Test func exporterWritesFeatureArtifactsAndManifest() throws {
    let root = try fxTempDir(); defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("__Snapshots__/MyTests", isDirectory: true)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try Data([0x89]).write(to: source.appendingPathComponent("t.01-welcome-iPhone15Pro-light.png"))
    try Data([0x89]).write(to: source.appendingPathComponent("t.02-login-iPhone15Pro-light.png"))

    let flow = DocumentedFlow(name: "Onboarding", summary: "s")
    let screens = [
        DocumentedScreen(title: "Welcome", description: "d", devices: [fxDevice("iPhone15Pro")], themes: [.light],
                         transitions: [.to("Login")]),
        DocumentedScreen(title: "Login", description: "d", devices: [fxDevice("iPhone15Pro")], themes: [.light]),
    ]
    let exporter = FlowExplorerExporter(flow: flow, screens: screens,
                                        snapshotSourcePath: source.path,
                                        configuration: .init(deviceFrames: false))
    let result = try exporter.export(at: root.appendingPathComponent("FlowExplorer").path)

    #expect(result.screenCount == 2)
    #expect(result.edgeCount == 1)
    #expect(result.imageCount == 2)
    let featureDir = root.appendingPathComponent("FlowExplorer/Onboarding")
    #expect(FileManager.default.fileExists(atPath: featureDir.appendingPathComponent("feature.json").path))
    #expect(FileManager.default.fileExists(atPath: featureDir.appendingPathComponent("flows.js").path))
    #expect(FileManager.default.fileExists(atPath: featureDir.appendingPathComponent("images/01-welcome-iPhone15Pro-light.png").path))

    let json = try Data(contentsOf: featureDir.appendingPathComponent("feature.json"))
    let feature = try JSONDecoder().decode(FlowData.Feature.self, from: json)
    #expect(feature.screens.first?.thumbnail == "images/01-welcome-iPhone15Pro-light.png")
    #expect(feature.edges == [.init(from: "welcome", to: "login", label: nil)])

    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("FlowExplorer/manifest.js").path))

    let explorer = root.appendingPathComponent("FlowExplorer")
    #expect(FileManager.default.fileExists(atPath: explorer.appendingPathComponent("index.html").path))
    #expect(FileManager.default.fileExists(atPath: explorer.appendingPathComponent("app.js").path))
    #expect(FileManager.default.fileExists(atPath: explorer.appendingPathComponent("vendor/cytoscape.min.js").path))
}

@MainActor
@Test func exporterRefreshesStaleAssets() throws {
    let root = try fxTempDir(); defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("__Snapshots__/MyTests", isDirectory: true)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try Data([0x89]).write(to: source.appendingPathComponent("t.01-welcome-iPhone15Pro-light.png"))

    let flow = DocumentedFlow(name: "Onboarding", summary: "s")
    let screens = [DocumentedScreen(title: "Welcome", description: "d", devices: [fxDevice("iPhone15Pro")], themes: [.light])]
    let exporter = FlowExplorerExporter(flow: flow, screens: screens, snapshotSourcePath: source.path, configuration: .init(deviceFrames: false))
    let explorerPath = root.appendingPathComponent("FlowExplorer").path
    _ = try exporter.export(at: explorerPath)

    // Tamper with the deployed app.js and backdate it so the bundled copy looks newer.
    let appJS = "\(explorerPath)/app.js"
    try "STALE".write(toFile: appJS, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.modificationDate: Date.distantPast], ofItemAtPath: appJS)

    _ = try exporter.export(at: explorerPath)
    let refreshed = try String(contentsOfFile: appJS, encoding: .utf8)
    #expect(refreshed != "STALE")
}

@MainActor
@Test func rebuildManifestListsFeatureMarkers() throws {
    let root = try fxTempDir(); defer { try? FileManager.default.removeItem(at: root) }
    let explorer = root.appendingPathComponent("FlowExplorer")
    for name in ["Onboarding", "Checkout"] {
        let dir = explorer.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let feature = FlowData.Feature(name: name, summary: "", screens: [], edges: [])
        try FlowData.encoder.encode(feature).write(to: dir.appendingPathComponent("feature.json"))
    }
    try FlowExplorer.rebuildManifest(at: explorer.path)
    let js = try String(contentsOf: explorer.appendingPathComponent("manifest.js"), encoding: .utf8)
    #expect(js.contains("Onboarding"))
    #expect(js.contains("Checkout"))
}
