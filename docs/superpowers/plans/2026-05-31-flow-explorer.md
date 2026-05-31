# Flow Explorer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `exportFlowExplorer`, which emits a static, interactive, multi-feature web bundle (Cytoscape.js + dagre) visualizing a tested feature's screens as a branching graph with framed-snapshot thumbnail nodes and a per-screen variants panel.

**Architecture:** The library emits a neutral data contract (per-feature `flows.js` + top-level `manifest.js`) plus framed snapshot images, and copies a vendored, build-free Cytoscape renderer next to it. Rendering is decoupled from data. Snapshot image resolution/copy/framing is shared between the DocC generator and the new exporter via an extracted `SnapshotImageCopier`.

**Tech Stack:** Swift 5.9, SwiftPM resources (`Bundle.module`), Foundation, CoreGraphics/ImageIO (existing device-frame renderer), Cytoscape.js + dagre + cytoscape-dagre (vendored static JS), swift-testing for tests.

---

## Conventions for every task

- **Test runner:** snapshot capture is iOS-only, so tests run on an iOS simulator. Boot one first if needed: `xcrun simctl boot 'iPhone 15 Pro'` (ignore "already booted").
- **Run the unit test target:**
  ```sh
  xcodebuild test \
    -scheme SwiftSnapshotDocumentation \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    -only-testing:SwiftSnapshotDocumentationTests 2>&1 | grep -iE "✔|✘|error:|Test run with|TEST (SUCCEEDED|FAILED)"
  ```
  (xcodebuild builds the whole scheme, so this also compiles the library and example target.)
- All new Swift files start with the standard header comment block matching existing files.
- Commit after each task.

## File structure (decomposition)

- `Sources/.../Models/ScreenTransition.swift` (new) — edge value type.
- `Sources/.../Models/DocumentedScreen.swift` (modify) — add `transitions`.
- `Sources/.../Models/ExportedFeature.swift` (new) — export result.
- `Sources/.../Models/FlowData.swift` (new) — Codable contract structs for `flows.js`.
- `Sources/.../Core/FlowEdgeResolver.swift` (new) — pure screens→edges resolution.
- `Sources/.../Core/SnapshotImageCopier.swift` (new) — shared resolve/index/copy+frame.
- `Sources/.../Core/DoCCGenerator.swift` (modify) — use `SnapshotImageCopier`.
- `Sources/.../Core/FlowExplorerExporter.swift` (new) — build data, write artifacts, assets, manifest.
- `Sources/.../Core/DocumentedFlow.swift` (modify) — `transitions:` on `addScreen`, `exportFlowExplorer`, `FlowExplorer` enum.
- `Sources/.../Resources/FlowExplorerAssets/{index.html, app.js, vendor/*}` (new) — web bundle.
- `Package.swift` (modify) — declare the resources.
- `Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift` (new) — all new tests.

---

## Task 1: `ScreenTransition` model

**Files:**
- Create: `Sources/SwiftSnapshotDocumentation/Models/ScreenTransition.swift`
- Test: `Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift`:
```swift
import Testing
import Foundation
@testable import SwiftSnapshotDocumentation

@Test func screenTransitionFactorySetsTargetAndLabel() {
    let t1 = ScreenTransition.to("Success", on: "valid")
    #expect(t1.target == "Success")
    #expect(t1.label == "valid")

    let t2 = ScreenTransition.to("Home")
    #expect(t2.target == "Home")
    #expect(t2.label == nil)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the unit test target (see Conventions). Expected: FAIL — `Cannot find 'ScreenTransition' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Sources/SwiftSnapshotDocumentation/Models/ScreenTransition.swift`:
```swift
//
//  ScreenTransition.swift
//  SwiftSnapshotDocumentation
//

import Foundation

/// A directed connection from one ``DocumentedScreen`` to another in a flow.
///
/// Use ``to(_:on:)`` to declare branches and loops, e.g.
/// `.to("Success", on: "valid")` and `.to("Error", on: "invalid")`.
public struct ScreenTransition: Sendable, Equatable {
    /// The target screen's title or id (resolved against screen ids at export time).
    public let target: String

    /// An optional trigger/condition rendered on the edge (e.g. "valid").
    public let label: String?

    public init(target: String, label: String? = nil) {
        self.target = target
        self.label = label
    }

    /// Creates a transition to the screen with the given title/id.
    public static func to(_ target: String, on label: String? = nil) -> ScreenTransition {
        ScreenTransition(target: target, label: label)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the unit test target. Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add Sources/SwiftSnapshotDocumentation/Models/ScreenTransition.swift Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift
git commit -m "feat: add ScreenTransition model"
```

---

## Task 2: Add `transitions` to `DocumentedScreen` and `addScreen`

**Files:**
- Modify: `Sources/SwiftSnapshotDocumentation/Models/DocumentedScreen.swift`
- Modify: `Sources/SwiftSnapshotDocumentation/Core/DocumentedFlow.swift`
- Test: `Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `FlowExplorerTests.swift`:
```swift
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the unit test target. Expected: FAIL — extra argument `transitions` in call.

- [ ] **Step 3: Add the property to `DocumentedScreen`**

In `DocumentedScreen.swift`, add the stored property after `callouts`:
```swift
    /// Optional callouts to include in the documentation.
    public let callouts: [Callout]

    /// Outgoing transitions to other screens (used by the Flow Explorer).
    public let transitions: [ScreenTransition]
```
Add the init parameter (after `callouts: [Callout] = []`) and assignment:
```swift
        callouts: [Callout] = [],
        transitions: [ScreenTransition] = []
    ) {
        self.id = id ?? title.sanitizedForFilename()
        self.title = title
        self.description = description
        self.discussion = discussion
        self.devices = devices
        self.themes = themes
        self.callouts = callouts
        self.transitions = transitions
    }
```

- [ ] **Step 4: Thread `transitions` through `addScreen`**

In `DocumentedFlow.swift`, add the parameter to `addScreen` (after `callouts: [DocumentedScreen.Callout] = []`):
```swift
        callouts: [DocumentedScreen.Callout] = [],
        transitions: [ScreenTransition] = [],
        file: StaticString = #file,
```
And pass it into the `DocumentedScreen(...)` construction in `addScreen`:
```swift
        let screen = DocumentedScreen(
            title: title,
            description: description,
            discussion: discussion,
            devices: devices,
            themes: themes,
            callouts: callouts,
            transitions: transitions
        )
```

- [ ] **Step 5: Run test to verify it passes**

Run the unit test target. Expected: PASS (and the existing suite stays green).

- [ ] **Step 6: Commit**

```sh
git add Sources/SwiftSnapshotDocumentation/Models/DocumentedScreen.swift Sources/SwiftSnapshotDocumentation/Core/DocumentedFlow.swift Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift
git commit -m "feat: carry screen transitions through addScreen"
```

---

## Task 3: `FlowEdgeResolver` — screens → resolved edges

**Files:**
- Create: `Sources/SwiftSnapshotDocumentation/Core/FlowEdgeResolver.swift`
- Test: `Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `FlowExplorerTests.swift`:
```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run the unit test target. Expected: FAIL — `Cannot find 'FlowEdgeResolver'`.

- [ ] **Step 3: Implement `FlowEdgeResolver`**

Create `Sources/SwiftSnapshotDocumentation/Core/FlowEdgeResolver.swift`:
```swift
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
```

Note: `sanitizedForFilename()` is the existing `String` extension in `DocumentedScreen.swift` (lowercases + hyphenates), so `"Success"` → `"success"` matches the screen id.

- [ ] **Step 4: Run tests to verify they pass**

Run the unit test target. Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add Sources/SwiftSnapshotDocumentation/Core/FlowEdgeResolver.swift Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift
git commit -m "feat: resolve flow screens into branching edges"
```

---

## Task 4: `ExportedFeature` result model

**Files:**
- Create: `Sources/SwiftSnapshotDocumentation/Models/ExportedFeature.swift`
- Test: `Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift`

- [ ] **Step 1: Write the failing test**

Append:
```swift
@Test func exportedFeatureStoresCounts() {
    let f = ExportedFeature(featurePath: "/x/Onboarding", screenCount: 3, edgeCount: 2, imageCount: 6, unresolvedTransitions: [])
    #expect(f.screenCount == 3)
    #expect(f.edgeCount == 2)
    #expect(f.imageCount == 6)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the unit test target. Expected: FAIL — `Cannot find 'ExportedFeature'`.

- [ ] **Step 3: Implement**

Create `Sources/SwiftSnapshotDocumentation/Models/ExportedFeature.swift`:
```swift
//
//  ExportedFeature.swift
//  SwiftSnapshotDocumentation
//

import Foundation

/// The result of exporting one feature into a Flow Explorer bundle.
public struct ExportedFeature: Sendable, Equatable {
    /// Path to the feature's directory inside the explorer bundle.
    public let featurePath: String
    public let screenCount: Int
    public let edgeCount: Int
    public let imageCount: Int
    /// "Source → target" strings for transitions whose target screen was not found.
    public let unresolvedTransitions: [String]

    public init(featurePath: String, screenCount: Int, edgeCount: Int, imageCount: Int, unresolvedTransitions: [String]) {
        self.featurePath = featurePath
        self.screenCount = screenCount
        self.edgeCount = edgeCount
        self.imageCount = imageCount
        self.unresolvedTransitions = unresolvedTransitions
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the unit test target. Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add Sources/SwiftSnapshotDocumentation/Models/ExportedFeature.swift Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift
git commit -m "feat: add ExportedFeature result model"
```

---

## Task 5: Extract `SnapshotImageCopier` (shared resolve / index / copy+frame)

**Files:**
- Create: `Sources/SwiftSnapshotDocumentation/Core/SnapshotImageCopier.swift`
- Modify: `Sources/SwiftSnapshotDocumentation/Core/DoCCGenerator.swift`
- Test: `Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift`

- [ ] **Step 1: Write the failing test**

Append (reuses helpers `makeTempDir`, `makeTopRedBottomBlueImage`, `writePNG`, `writeDummyImage` from `DocumentationGenerationTests.swift` — they are file-private there, so add small local equivalents here):
```swift
private func tempDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("ssd-fx-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func snapshotImageCopierStripsPrefixAndIndexes() throws {
    let dir = try tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    try Data([0x89]).write(to: dir.appendingPathComponent("testFoo.01-welcome-iPhone15Pro-light.png"))
    let index = try SnapshotImageCopier.index(at: dir.path, fileManager: .default)
    #expect(index["01-welcome-iPhone15Pro-light.png"] != nil)
}

@Test func snapshotImageCopierCopiesPlainImage() throws {
    let dir = try tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let src = dir.appendingPathComponent("a.png"); try Data([0x89, 0x50]).write(to: src)
    let dest = dir.appendingPathComponent("out/a.png")
    try SnapshotImageCopier.copyImage(from: src.path, to: dest.path, frame: nil)
    #expect(FileManager.default.fileExists(atPath: dest.path))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the unit test target. Expected: FAIL — `Cannot find 'SnapshotImageCopier'`.

- [ ] **Step 3: Implement `SnapshotImageCopier`**

Create `Sources/SwiftSnapshotDocumentation/Core/SnapshotImageCopier.swift`:
```swift
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
```

- [ ] **Step 4: Refactor `DoCCGenerator` to use it (keep behavior identical)**

In `DoCCGenerator.swift`, replace the body of `copySnapshotImages(to:)` and delete the now-duplicated private helpers (`resolveSnapshotSourcePath`, `copyImagesRecursively`, `strippedSnapshotName`). Keep `device(forImageName:)` and `knownDevices`. New `copySnapshotImages`:
```swift
    @discardableResult
    private func copySnapshotImages(to destinationPath: String) throws -> Int {
        let fileManager = FileManager.default
        let (sourcePath, searched) = SnapshotImageCopier.resolveSourceDirectory(provided: snapshotSourcePath, fileManager: fileManager)
        guard let sourcePath else { throw DocumentationError.snapshotsNotFound(searchedPaths: searched) }

        let index = try SnapshotImageCopier.index(at: sourcePath, fileManager: fileManager)
        var copied = 0
        for (cleanedName, sourceFilePath) in index {
            let device = device(forImageName: cleanedName)
            let subdir = (configuration.organizeByDevice && device != nil) ? "/\(device!.name)" : ""
            let destPath = "\(destinationPath)\(subdir)/\(cleanedName)"
            let frame = (configuration.deviceFrames ? device?.frame : nil)
            try SnapshotImageCopier.copyImage(from: sourceFilePath, to: destPath, frame: frame)
            copied += 1
        }
        guard copied > 0 else { throw DocumentationError.noSnapshotsCopied(sourcePath: sourcePath) }
        print("📸 Copied \(copied) snapshot images from \(sourcePath)")
        return copied
    }
```

- [ ] **Step 5: Run the full unit test target (refactor must keep everything green)**

Run the unit test target. Expected: PASS — including the pre-existing `generateCopiesSnapshotsAndStripsTestNamePrefix`, `generateFramesImagesWhenDeviceFramesEnabled`, `generateGroupsImagesByDeviceWhenEnabled`, `generateThrowsWhenSnapshotsDirectoryIsEmpty/Missing`, plus the two new copier tests.

- [ ] **Step 6: Commit**

```sh
git add Sources/SwiftSnapshotDocumentation/Core/SnapshotImageCopier.swift Sources/SwiftSnapshotDocumentation/Core/DoCCGenerator.swift Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift
git commit -m "refactor: extract SnapshotImageCopier shared by generator and explorer"
```

---

## Task 6: `FlowData` Codable contract

**Files:**
- Create: `Sources/SwiftSnapshotDocumentation/Models/FlowData.swift`
- Test: `Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift`

- [ ] **Step 1: Write the failing test**

Append:
```swift
@Test func flowDataEncodesToStableJSON() throws {
    let feature = FlowData.Feature(
        name: "Onboarding", summary: "s",
        screens: [.init(id: "welcome", title: "Welcome", description: "d",
                        thumbnail: "images/01-welcome-iPhone15Pro-light.png",
                        variants: [.init(device: "iPhone15Pro", theme: "light", image: "images/01-welcome-iPhone15Pro-light.png")],
                        callouts: [.init(type: "tip", content: "hi")])],
        edges: [.init(from: "welcome", to: "login", label: "next")])
    let data = try FlowData.encoder.encode(feature)
    let decoded = try JSONDecoder().decode(FlowData.Feature.self, from: data)
    #expect(decoded == feature)
    #expect(decoded.screens.first?.thumbnail == "images/01-welcome-iPhone15Pro-light.png")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the unit test target. Expected: FAIL — `Cannot find 'FlowData'`.

- [ ] **Step 3: Implement**

Create `Sources/SwiftSnapshotDocumentation/Models/FlowData.swift`:
```swift
//
//  FlowData.swift
//  SwiftSnapshotDocumentation
//

import Foundation

/// Codable shapes for the neutral data contract written to `flows.js` / `manifest.js`.
enum FlowData {
    struct Feature: Codable, Equatable {
        let name: String
        let summary: String
        let screens: [Screen]
        let edges: [Edge]
    }
    struct Screen: Codable, Equatable {
        let id: String
        let title: String
        let description: String
        let thumbnail: String
        let variants: [Variant]
        let callouts: [Callout]
    }
    struct Variant: Codable, Equatable {
        let device: String
        let theme: String
        let image: String
    }
    struct Callout: Codable, Equatable {
        let type: String
        let content: String
    }
    struct Edge: Codable, Equatable {
        let from: String
        let to: String
        let label: String?
    }
    struct ManifestEntry: Codable, Equatable {
        let name: String
        let dir: String
    }
    struct Manifest: Codable, Equatable {
        let features: [ManifestEntry]
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the unit test target. Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add Sources/SwiftSnapshotDocumentation/Models/FlowData.swift Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift
git commit -m "feat: add FlowData Codable contract"
```

---

## Task 7: Vendored web assets + Package resources

**Files:**
- Create: `Sources/SwiftSnapshotDocumentation/Resources/FlowExplorerAssets/index.html`
- Create: `Sources/SwiftSnapshotDocumentation/Resources/FlowExplorerAssets/app.js`
- Create: `Sources/SwiftSnapshotDocumentation/Resources/FlowExplorerAssets/vendor/{cytoscape.min.js, dagre.min.js, cytoscape-dagre.js}`
- Modify: `Package.swift`

- [ ] **Step 1: Vendor the third-party JS (exact versions, no build step)**

```sh
mkdir -p Sources/SwiftSnapshotDocumentation/Resources/FlowExplorerAssets/vendor
cd Sources/SwiftSnapshotDocumentation/Resources/FlowExplorerAssets/vendor
curl -fsSL https://unpkg.com/cytoscape@3.30.2/dist/cytoscape.min.js -o cytoscape.min.js
curl -fsSL https://unpkg.com/dagre@0.8.5/dist/dagre.min.js -o dagre.min.js
curl -fsSL https://unpkg.com/cytoscape-dagre@2.5.0/cytoscape-dagre.js -o cytoscape-dagre.js
cd -
# sanity: each file should be non-empty
wc -c Sources/SwiftSnapshotDocumentation/Resources/FlowExplorerAssets/vendor/*.js
```

- [ ] **Step 2: Create `index.html`**

Create `Sources/SwiftSnapshotDocumentation/Resources/FlowExplorerAssets/index.html`:
```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Flow Explorer</title>
  <style>
    * { box-sizing: border-box; }
    body { margin: 0; font: 14px -apple-system, system-ui, sans-serif; height: 100vh; display: flex; color: #111; }
    #sidebar { width: 220px; border-right: 1px solid #e3e3e3; overflow: auto; padding: 12px; }
    #sidebar h1 { font-size: 13px; text-transform: uppercase; color: #888; letter-spacing: .04em; }
    #features { list-style: none; margin: 0; padding: 0; }
    #features li { padding: 8px 10px; border-radius: 8px; cursor: pointer; }
    #features li.active, #features li:hover { background: #eef2ff; }
    #main { flex: 1; position: relative; }
    #cy { position: absolute; inset: 0; }
    #panel { position: absolute; top: 0; right: 0; width: 340px; height: 100%; background: #fff;
             border-left: 1px solid #e3e3e3; padding: 16px; overflow: auto; transform: translateX(100%);
             transition: transform .2s; }
    #panel.open { transform: translateX(0); }
    #panel img { width: 100%; border: 1px solid #eee; border-radius: 10px; margin-bottom: 8px; }
    #panel .close { float: right; cursor: pointer; color: #888; }
    .variant-label { font-size: 12px; color: #666; margin: 4px 0; }
  </style>
</head>
<body>
  <div id="sidebar"><h1>Features</h1><ul id="features"></ul></div>
  <div id="main"><div id="cy"></div>
    <div id="panel"><span class="close" onclick="closePanel()">✕</span><div id="panel-body"></div></div>
  </div>
  <script src="vendor/cytoscape.min.js"></script>
  <script src="vendor/dagre.min.js"></script>
  <script src="vendor/cytoscape-dagre.js"></script>
  <script src="manifest.js"></script>
  <script src="app.js"></script>
</body>
</html>
```

- [ ] **Step 3: Create `app.js`**

Create `Sources/SwiftSnapshotDocumentation/Resources/FlowExplorerAssets/app.js`:
```js
/* Flow Explorer renderer. Reads window.FLOW_MANIFEST and window.FLOW_DATA. */
(function () {
  var cy = null;
  var currentDir = null;

  function loadFeature(entry) {
    currentDir = entry.dir;
    // Each feature's flows.js assigns window.FLOW_DATA[name]; load it on demand.
    var existing = window.FLOW_DATA && window.FLOW_DATA[entry.name];
    if (existing) return render(existing, entry.dir);
    var s = document.createElement("script");
    s.src = entry.dir + "/flows.js";
    s.onload = function () { render(window.FLOW_DATA[entry.name], entry.dir); };
    document.body.appendChild(s);
  }

  function render(feature, dir) {
    closePanel();
    var elements = [];
    feature.screens.forEach(function (sc) {
      elements.push({ data: { id: sc.id, label: sc.title, img: dir + "/" + sc.thumbnail, screen: sc, dir: dir } });
    });
    feature.edges.forEach(function (e) {
      elements.push({ data: { source: e.from, target: e.to, label: e.label || "" } });
    });
    if (cy) cy.destroy();
    cy = cytoscape({
      container: document.getElementById("cy"),
      elements: elements,
      style: [
        { selector: "node", style: {
            "background-image": "data(img)", "background-fit": "contain", "background-opacity": 0,
            "shape": "round-rectangle", "width": 120, "height": 240, "border-width": 1,
            "border-color": "#ddd", "label": "data(label)", "text-valign": "bottom",
            "text-margin-y": 6, "font-size": 12 } },
        { selector: "edge", style: {
            "curve-style": "bezier", "target-arrow-shape": "triangle",
            "line-color": "#bbb", "target-arrow-color": "#bbb", "width": 2,
            "label": "data(label)", "font-size": 10, "color": "#666",
            "text-background-color": "#fff", "text-background-opacity": 1 } }
      ],
      layout: { name: "dagre", rankDir: "TB", nodeSep: 40, rankSep: 70 }
    });
    cy.on("tap", "node", function (evt) { openPanel(evt.target.data("screen"), dir); });
  }

  function openPanel(screen, dir) {
    var body = document.getElementById("panel-body");
    var html = "<h2>" + escapeHtml(screen.title) + "</h2><p>" + escapeHtml(screen.description) + "</p>";
    (screen.callouts || []).forEach(function (c) {
      html += "<p><strong>" + escapeHtml(c.type) + ":</strong> " + escapeHtml(c.content) + "</p>";
    });
    screen.variants.forEach(function (v) {
      html += '<div class="variant-label">' + escapeHtml(v.device + " · " + v.theme) + "</div>";
      html += '<img src="' + dir + "/" + v.image + '" alt="" />';
    });
    body.innerHTML = html;
    document.getElementById("panel").classList.add("open");
  }

  window.closePanel = function () { document.getElementById("panel").classList.remove("open"); };

  function escapeHtml(s) {
    return String(s).replace(/[&<>"]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
    });
  }

  function init() {
    var manifest = window.FLOW_MANIFEST || { features: [] };
    var list = document.getElementById("features");
    manifest.features.forEach(function (entry, i) {
      var li = document.createElement("li");
      li.textContent = entry.name;
      li.onclick = function () {
        Array.prototype.forEach.call(list.children, function (n) { n.classList.remove("active"); });
        li.classList.add("active");
        loadFeature(entry);
      };
      list.appendChild(li);
      if (i === 0) li.click();
    });
  }
  init();
})();
```

- [ ] **Step 4: Declare resources in `Package.swift`**

In `Package.swift`, change the main library target to include resources:
```swift
        .target(
            name: "SwiftSnapshotDocumentation",
            dependencies: [
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            resources: [
                .copy("Resources/FlowExplorerAssets")
            ]
        ),
```

- [ ] **Step 5: Verify it builds with resources**

Run: `xcodebuild build -scheme SwiftSnapshotDocumentation -destination 'platform=iOS Simulator,name=iPhone 15 Pro' 2>&1 | grep -iE "error:|BUILD (SUCCEEDED|FAILED)"`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```sh
git add Sources/SwiftSnapshotDocumentation/Resources Package.swift
git commit -m "feat: vendor Flow Explorer web bundle as package resources"
```

---

## Task 8: `FlowExplorerExporter` — build feature data + write artifacts + manifest

**Files:**
- Create: `Sources/SwiftSnapshotDocumentation/Core/FlowExplorerExporter.swift`
- Test: `Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift`

- [ ] **Step 1: Write the failing tests**

Append (uses a device built without the iOS-only statics so it runs anywhere):
```swift
private func fxDevice(_ name: String) -> DeviceConfiguration {
    #if os(iOS)
    return DeviceConfiguration(name: name, viewImageConfig: .iPhone13Pro)
    #else
    return DeviceConfiguration(name: name, viewImageConfig: 0)
    #endif
}

@MainActor
@Test func exporterWritesFeatureArtifactsAndManifest() throws {
    let root = try tempDir(); defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("__Snapshots__/MyTests", isDirectory: true)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    // recorded files: "<testName>.NN-<id>-<device>-<theme>.png"
    try Data([0x89]).write(to: source.appendingPathComponent("t.01-welcome-iPhone15Pro-light.png"))

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
    let featureDir = root.appendingPathComponent("FlowExplorer/Onboarding")
    #expect(FileManager.default.fileExists(atPath: featureDir.appendingPathComponent("feature.json").path))
    #expect(FileManager.default.fileExists(atPath: featureDir.appendingPathComponent("flows.js").path))
    #expect(FileManager.default.fileExists(atPath: featureDir.appendingPathComponent("images/01-welcome-iPhone15Pro-light.png").path))

    // flows.js wraps JSON; the embedded feature.json is pure JSON and decodable.
    let json = try Data(contentsOf: featureDir.appendingPathComponent("feature.json"))
    let feature = try JSONDecoder().decode(FlowData.Feature.self, from: json)
    #expect(feature.screens.first?.thumbnail == "images/01-welcome-iPhone15Pro-light.png")
    #expect(feature.edges == [.init(from: "welcome", to: "login", label: nil)])

    // manifest.js exists and the embedded JSON lists the feature.
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("FlowExplorer/manifest.js").path))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the unit test target. Expected: FAIL — `Cannot find 'FlowExplorerExporter'`.

- [ ] **Step 3: Implement `FlowExplorerExporter`**

Create `Sources/SwiftSnapshotDocumentation/Core/FlowExplorerExporter.swift`:
```swift
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

        // Resolve + index the source snapshots.
        let (sourcePath, searched) = SnapshotImageCopier.resolveSourceDirectory(provided: snapshotSourcePath, fileManager: fileManager)
        guard let sourcePath else { throw DocumentationError.snapshotsNotFound(searchedPaths: searched) }
        let index = try SnapshotImageCopier.index(at: sourcePath, fileManager: fileManager)

        // Build screen data + copy each variant's image.
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

        // Resolve edges.
        let resolved = FlowEdgeResolver.resolve(screens: screens)
        let edges = resolved.edges.map { FlowData.Edge(from: $0.from, to: $0.to, label: $0.label) }
        for u in resolved.unresolved { print("⚠️  Flow Explorer: unresolved transition \(u)") }

        // Write feature.json + flows.js (JS global wrapper to avoid file:// CORS).
        let feature = FlowData.Feature(name: flow.name, summary: flow.summary, screens: screenData, edges: edges)
        let json = try FlowData.encoder.encode(feature)
        try json.write(to: URL(fileURLWithPath: "\(featureDir)/feature.json"))
        let jsonString = String(decoding: json, as: UTF8.self)
        let flowsJS = """
        window.FLOW_DATA = window.FLOW_DATA || {};
        window.FLOW_DATA[\(stringLiteral(flow.name))] = \(jsonString);
        """
        try flowsJS.write(toFile: "\(featureDir)/flows.js", atomically: true, encoding: .utf8)

        // Copy bundle assets (index.html / app.js / vendor) if absent.
        try copyAssetsIfNeeded(to: explorerPath, fileManager: fileManager)

        // Rebuild manifest.js from feature.json markers.
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
```

Note: `DocumentedScreen.Callout.CalloutType` is a `String`-raw enum, so `$0.type.rawValue` yields "Tip"/"Note"/etc. `DocumentationConfiguration.ImageFormat.rawValue` is "png"/"jpg".

- [ ] **Step 4: Run tests to verify they pass**

Run the unit test target. Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add Sources/SwiftSnapshotDocumentation/Core/FlowExplorerExporter.swift Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift
git commit -m "feat: FlowExplorerExporter writes feature data, images, and manifest"
```

---

## Task 9: Public `exportFlowExplorer` + `FlowExplorer.rebuildManifest`

**Files:**
- Modify: `Sources/SwiftSnapshotDocumentation/Core/DocumentedFlow.swift`
- Test: `Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift`

- [ ] **Step 1: Write the failing test**

The public `exportFlowExplorer` path (which requires capturing via `addScreen` on iOS)
is covered end-to-end by the example test in Task 10. Here we unit-test only the pure
`FlowExplorer.rebuildManifest`. Append:
```swift
@Test func rebuildManifestListsFeatureMarkers() throws {
    let root = try tempDir(); defer { try? FileManager.default.removeItem(at: root) }
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run the unit test target. Expected: FAIL — `Cannot find 'FlowExplorer'` / `has no member 'exportFlowExplorer'`.

- [ ] **Step 3: Implement the public API**

In `DocumentedFlow.swift`, add the method to `DocumentedFlow` (next to `generateDocumentation`):
```swift
    /// Exports this flow into a Flow Explorer bundle at `explorerPath`.
    ///
    /// Writes `<Name>/{feature.json, flows.js, images/}`, copies the vendored web
    /// bundle (index.html/app.js/vendor) if absent, and rebuilds `manifest.js`.
    /// Shares the capture prerequisite of ``generateDocumentation(outputPath:snapshotSourcePath:configuration:)``:
    /// snapshots must already exist (captured on iOS, or committed baselines).
    ///
    /// - Returns: An ``ExportedFeature`` describing what was written.
    @discardableResult
    public func exportFlowExplorer(
        at explorerPath: String,
        snapshotSourcePath: String? = nil,
        configuration: DocumentationConfiguration? = nil
    ) async throws -> ExportedFeature {
        let exporter = FlowExplorerExporter(
            flow: self,
            screens: screens,
            snapshotSourcePath: snapshotSourcePath ?? resolvedSnapshotDirectory,
            configuration: configuration ?? self.configuration
        )
        #if os(iOS)
        let captureSupported = true
        #else
        let captureSupported = false
        #endif
        do {
            return try exporter.export(at: explorerPath)
        } catch let error as DocumentationError {
            throw Self.mappedGenerationError(error, captureSupported: captureSupported)
        }
    }
```
Add the `FlowExplorer` enum at the bottom of `DocumentedFlow.swift` (outside the class):
```swift
/// Entry points for maintaining a Flow Explorer bundle.
public enum FlowExplorer {
    /// Rebuilds `manifest.js` from the `feature.json` markers in `explorerPath`.
    /// Use once after all documentation tests run to guarantee a complete index.
    @MainActor
    public static func rebuildManifest(at explorerPath: String) throws {
        try FlowExplorerExporter.writeManifest(at: explorerPath, fileManager: .default)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the unit test target. Expected: PASS (full suite green).

- [ ] **Step 5: Commit**

```sh
git add Sources/SwiftSnapshotDocumentation/Core/DocumentedFlow.swift Tests/SwiftSnapshotDocumentationTests/FlowExplorerTests.swift
git commit -m "feat: public exportFlowExplorer and FlowExplorer.rebuildManifest"
```

---

## Task 10: End-to-end check on the real example flow

**Files:**
- Modify: `Tests/ExampleFlowDocumentationTests/ExampleFlowDocumentationTests.swift`

- [ ] **Step 1: Add transitions + an explorer export to the example test**

In `ExampleFlowDocumentationTests.swift`, add `transitions:` to the first two `addScreen` calls to demonstrate branching: on the Welcome screen add `transitions: [.to("Login Screen")]`, and on the Login screen add `transitions: [.to("Profile Form - Empty", on: "new user")]`. After the existing `generateDocumentation(...)` call, add:
```swift
        let exported = try await flow.exportFlowExplorer(at: "FlowExplorer")
        print("🗂  Flow Explorer: \(exported.screenCount) screens, \(exported.edgeCount) edges at \(exported.featurePath)")
```

- [ ] **Step 2: Run the example on a simulator (verify mode)**

Run:
```sh
xcodebuild test -scheme SwiftSnapshotDocumentation \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:ExampleFlowDocumentationTests 2>&1 | grep -iE "Flow Explorer|TEST (SUCCEEDED|FAILED)"
```
Expected: `TEST SUCCEEDED` and a "Flow Explorer: 5 screens, … edges" line.

- [ ] **Step 3: Manually verify the bundle renders (one-time human check)**

Locate the generated `FlowExplorer` (under the simulator data container, like `ExampleFlow.docc` was), then:
```sh
open <path>/FlowExplorer/index.html
```
Confirm: feature listed in the sidebar; nodes show screen thumbnails; the Welcome→Login and Login→Profile edges render with labels; clicking a node opens the variants panel. (This is a manual visual check; the automated tests cover the data contract and file presence.)

- [ ] **Step 4: Commit**

```sh
git add Tests/ExampleFlowDocumentationTests/ExampleFlowDocumentationTests.swift
git commit -m "test: exercise Flow Explorer export in the example flow"
```

---

## Task 11: Documentation

**Files:**
- Modify: `README.md`, `AGENTS.md`, `Documentation/AgentSkill/swift-snapshot-documentation/SKILL.md`, `CLAUDE.md`

- [ ] **Step 1: README** — add a "Flow Explorer" subsection under Basic Usage showing `transitions:` on `addScreen` and a `try await flow.exportFlowExplorer(at: "FlowExplorer")` call, plus "open `FlowExplorer/index.html`" and the multi-feature note (`FlowExplorer.rebuildManifest` after all tests).

- [ ] **Step 2: AGENTS.md** — add `exportFlowExplorer(at:) -> ExportedFeature` and `ScreenTransition.to(_:on:)` to the API quick reference; add a row to the common-mistakes table ("flows.js fails to load over file://" → "we emit JS globals, so double-clicking index.html works; if you serve it, any static server is fine").

- [ ] **Step 3: SKILL.md** — add a short "Flow Explorer" section: declare `transitions:`, call `exportFlowExplorer(at:)`, open `index.html`, and call `FlowExplorer.rebuildManifest(at:)` once after all features for a complete index.

- [ ] **Step 4: CLAUDE.md** — under Architecture, document `FlowExplorerExporter`, `FlowEdgeResolver` (linear-fallback rule), `SnapshotImageCopier` (now shared with `DoCCGenerator`), the JS-globals/`file://` decision, and the derived-manifest + `rebuildManifest` aggregation.

- [ ] **Step 5: Run the full suite once more**

Run the unit test target and the example test (both on a simulator). Expected: both `TEST SUCCEEDED`.

- [ ] **Step 6: Commit**

```sh
git add README.md AGENTS.md Documentation/AgentSkill CLAUDE.md
git commit -m "docs: document the Flow Explorer feature"
```

---

## Self-review notes (for the implementer)

- **Spec coverage:** transitions (T1–T2), edge resolution + linear fallback + unresolved (T3), ExportedFeature (T4), shared image copier refactor (T5), neutral contract (T6), vendored bundle + resources + JS-globals/CORS (T7), exporter writing feature/manifest + framed images (T8), public API + rebuildManifest (T9), e2e + manual render check (T10), docs (T11). Race-safety is realized by isolated per-feature folders + derived manifest (T8) plus `rebuildManifest` (T9).
- **Thumbnail selection** = `variants.first` (first device, first theme), matching the spec.
- **Type consistency:** `FlowData.Feature/Screen/Variant/Edge/Callout/Manifest/ManifestEntry`, `FlowEdgeResolver.Edge {from,to,label}`, `ExportedFeature {featurePath,screenCount,edgeCount,imageCount,unresolvedTransitions}`, `SnapshotImageCopier.{strippedSnapshotName,resolveSourceDirectory,index,copyImage}` are referenced consistently across tasks.
- **No new behavior on macOS regression:** `exportFlowExplorer` reuses `mappedGenerationError`, so off-iOS with no baselines yields `captureUnavailable`, consistent with `generateDocumentation`.
