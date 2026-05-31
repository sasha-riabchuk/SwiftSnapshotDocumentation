# Swift Snapshot Documentation

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsasha-riabchuk%2FSwiftSnapshotDocumentation%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/sasha-riabchuk/SwiftSnapshotDocumentation)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsasha-riabchuk%2FSwiftSnapshotDocumentation%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/sasha-riabchuk/SwiftSnapshotDocumentation)
[![License](https://img.shields.io/github/license/sasha-riabchuk/SwiftSnapshotDocumentation)](https://github.com/sasha-riabchuk/SwiftSnapshotDocumentation/blob/main/LICENSE)

A library for generating beautiful DocC documentation from your SwiftUI screens with automatic snapshot testing across devices and themes.

* [What is Swift Snapshot Documentation?](#what-is-swift-snapshot-documentation)
* [Example Output](#example-output)
* [Examples](#examples)
* [Basic Usage](#basic-usage)
* [Using with AI coding agents](#using-with-ai-coding-agents)
* [Documentation](#documentation)
* [Installation](#installation)
* [Requirements](#requirements)
* [Community](#community)
* [License](#license)

## What is Swift Snapshot Documentation?

Swift Snapshot Documentation combines the power of [PointFree's swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) with Apple's DocC to solve several key challenges when building and maintaining iOS applications:

* **Visual Documentation**: Automatically generate comprehensive visual documentation of your UI screens across multiple devices and themes, integrated directly into Xcode's documentation viewer.

* **Design System Maintenance**: Document and validate UI components across light and dark modes, different device sizes, and various states, ensuring consistency throughout your application.

* **Visual Regression Testing**: Leverage snapshot testing to detect unintended UI changes in your CI/CD pipeline, combining documentation generation with test coverage.

* **Team Communication**: Share visual context of user flows and screens without requiring team members to build and run the app, improving code reviews and cross-functional collaboration.

* **Developer Onboarding**: Help new team members understand the application's UI structure and user flows through automatically generated, always-up-to-date visual documentation.

* **Interactive Flow Explorer**: Export a static, browser-based map of your screens as a branching graph (Cytoscape.js) — pan/zoom, toggle the whole flow between iPhone/iPad and light/dark, click any screen for its variants. Opens straight from `index.html` (no server). See [Flow Explorer](#flow-explorer).

## Example Output

The library generates DocC catalogs that integrate seamlessly with Xcode's documentation viewer. Here's what the generated documentation looks like:

### Generated DocC Catalog Structure

```
Documentation.docc/
├── OnboardingFlow.md                    # Main flow article
├── 01-welcome-screen.md                 # Individual screen articles
├── 02-login-screen.md
├── 03-profile-form.md
└── Resources/
    └── Snapshots/
        ├── 01-welcome-screen-iphone15pro-light.png
        ├── 01-welcome-screen-iphone15pro-dark.png
        ├── 01-welcome-screen-ipadpro129-light.png
        ├── 01-welcome-screen-ipadpro129-dark.png
        ├── 02-login-screen-iphone15pro-light.png
        └── ...
```

### Documentation Viewer

Each screen article includes:

* **Side-by-side theme comparison**: Light and dark mode screenshots displayed together
* **Multiple device sizes**: iPhone SE, iPhone 15 Pro, iPhone 15 Pro Max, iPad Pro 11", iPad Pro 12.9"
* **Rich documentation**: Full Markdown support with headings, lists, code blocks, and links
* **DocC callouts**: Note, Important, Warning, and Tip callouts for additional context
* **Navigation**: Links between screens to show user flow progression
* **Device frames**: Each image is composited into a procedurally-drawn device bezel (with a Dynamic Island on notch iPhones)

## Examples

This repo comes with a comprehensive example demonstrating the library's capabilities:

* [**Example Flow**](Tests/ExampleFlowDocumentationTests/): an onboarding flow (welcome, login, and profile states) across multiple devices and themes, plus a second **"iOS Components"** feature — a gallery of native components (alert, action sheet, sheets, popover, tab bar, navigation bar, toast). Both are exported into a single multi-feature Flow Explorer bundle.

Run the example to see the generated DocC catalog and Flow Explorer. Snapshot capture is iOS-only,
so run the tests on an iOS simulator (a plain `swift test` on macOS will not build
the example target, which references iOS-only device constants):

```sh
xcodebuild test \
  -scheme SwiftSnapshotDocumentation \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:ExampleFlowDocumentationTests
```

## Basic Usage

### Creating Documentation Tests

To document a feature or user flow, create a test case that defines the screens and generates the DocC catalog:

```swift
import XCTest
import SwiftSnapshotDocumentation
@testable import YourApp

@MainActor
final class OnboardingFlowDocumentation: XCTestCase {
    func testGenerateOnboardingDocs() async throws {
        // Verify by default (regression gate); record only when explicitly asked.
        let isRecording = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil

        // Define the flow
        let flow = DocumentedFlow(
            name: "Onboarding",
            summary: "New user onboarding experience",
            overview: """
            Complete onboarding flow from welcome screen to authenticated dashboard.
            This flow introduces new users to the app and guides them through account creation.
            """,
            record: isRecording ? .record : .verify
        )

        // Document each screen
        await flow.addScreen(
            title: "Welcome Screen",
            description: "Initial app introduction with key features",
            view: { WelcomeView() },
            devices: [.iPhone15Pro, .iPadPro129],
            themes: [.light, .dark]
        )

        await flow.addScreen(
            title: "Login Screen",
            description: "User authentication interface",
            view: { LoginView() },
            devices: [.iPhone15Pro],
            themes: [.light, .dark],
            callouts: [
                .init(type: .important, content: "Supports biometric authentication via Face ID and Touch ID")
            ]
        )

        // Generate the DocC catalog
        try await flow.generateDocumentation(
            outputPath: "Documentation.docc"
        )
    }
}
```

Run the test on an iOS simulator (snapshot capture is iOS-only). Set
`RECORD_SNAPSHOTS` in the scheme/test-plan environment to (re)generate snapshots:

```sh
xcodebuild test \
  -scheme YourAppScheme \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:YourAppTests/OnboardingFlowDocumentation
```

This creates:
- `Documentation.docc/` - DocC catalog with articles for each screen
- `__Snapshots__/` - Snapshot images referenced in the documentation

View the documentation in Xcode by opening `Documentation.docc` or building documentation with Product → Build Documentation (⌃⇧⌘D).

### Recording vs. verifying

A documentation flow does double duty, so the `record:` mode makes the intent explicit:

* **`.verify`** (use on CI) — compares each screen against the committed snapshots and **fails on any difference**. This is what turns the documentation test into a UI regression gate. Run `generateDocumentation` afterwards to rebuild the catalog from the verified images.
* **`.record`** (run locally) — (re)writes every snapshot, then regenerates the catalog. Commit the updated snapshots together with the catalog. Recording always reports a test failure by design, to remind you to review and re-run.
* **`.recordMissing`** — records only snapshots that don't exist yet and verifies the rest; handy when adding a new screen without disturbing existing baselines.

When `record:` is omitted, the ambient swift-snapshot-testing configuration is honored. Gate the choice behind an environment variable (set it in the scheme/test-plan environment so it reaches the simulator test process) so the same test verifies on CI and records on demand:

```swift
let flow = DocumentedFlow(
    name: "Onboarding",
    summary: "…",
    record: ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil ? .record : .verify
)
```

### Flow Explorer

Export an interactive, browser-based graph of your screen flow — framed snapshot thumbnails as nodes, directed edges as arrows — by calling `exportFlowExplorer`. Declare transitions between screens using the `transitions:` parameter on `addScreen` to express branches and alternate paths.

```swift
await flow.addScreen(
    title: "Welcome",
    description: "Landing screen",
    view: { WelcomeView() },
    devices: [.iPhone15Pro],
    themes: [.light, .dark],
    transitions: [
        .to("Login"),
        .to("Guest Browse", on: "continue as guest")
    ]
)

await flow.addScreen(
    title: "Login",
    description: "Authentication",
    view: { LoginView() },
    devices: [.iPhone15Pro],
    themes: [.light, .dark],
    transitions: [.to("Home")]
)

try await flow.exportFlowExplorer(at: "FlowExplorer")
```

Open `FlowExplorer/index.html` directly in a browser — data is emitted as JS globals (with embedded thumbnails) so `file://` works with **no server**. The viewer is a Figma-style canvas: pan/zoom, click a node to open the inspector with all of a screen's device × theme variants, and use the **toolbar** to flip the whole flow between **iPhone/iPad** and **Light/Dark** (the toggles appear only for the device families and themes your snapshots cover; nodes lacking the exact variant are dimmed and fall back to their closest one).

Note: when any screen declares `transitions:`, the linear fallback is disabled flow-wide, so screens without an incoming or outgoing transition appear as unconnected nodes — give every screen a transition for a fully connected graph.

To build a multi-feature explorer, call `exportFlowExplorer(at:)` with the same directory from each feature's test, then call `FlowExplorer.rebuildManifest(at: "FlowExplorer")` once after all features have been exported to finalize the shared index.

### Documenting Multiple View States

Document different states of the same screen by adding multiple screen entries:

```swift
// Empty state
await flow.addScreen(
    title: "Profile - Empty",
    description: "Initial empty state before user input",
    view: { ProfileView(data: nil) },
    devices: [.iPhone15Pro],
    themes: [.light, .dark]
)

// Filled state
await flow.addScreen(
    title: "Profile - Filled",
    description: "Form populated with user data",
    view: { ProfileView(data: mockUserData) },
    devices: [.iPhone15Pro],
    themes: [.light, .dark]
)
```

### Available Devices and Themes

```swift
// Individual devices
.iPhoneSE, .iPhone15Pro, .iPhone15ProMax, .iPadPro11, .iPadPro129

// Device groups
.allIPhones  // All iPhone sizes
.allIPads    // All iPad sizes
.allDevices  // All supported devices

// Themes
.light, .dark, .allThemes
```

### Documentation Configuration

Customize the generated documentation with `DocumentationConfiguration`:

```swift
let config = DocumentationConfiguration(
    imageFormat: .png,              // Image format (.png or .jpeg)
    deviceFrames: true,             // Composite a device bezel around each image
    perPixelTolerance: 0.01,        // Per-pixel comparison tolerance
    overallTolerance: 0.05,         // Fraction of pixels allowed to differ
    createIndexPage: true,          // Curate a Topics → Screens listing on the root page
    includeFlowDiagram: false,      // Add a Mermaid flow diagram of the screen sequence
    organizeByDevice: false         // Group catalog images into per-device subfolders
)

// Pass the configuration at flow creation so the comparison tolerances take
// effect while snapshots are captured.
let flow = DocumentedFlow(
    name: "Onboarding",
    summary: "New user onboarding experience",
    configuration: config
)
```

The tolerances are mapped onto swift-snapshot-testing's `.image` strategy:
`overallTolerance` becomes `precision` (`1 - overallTolerance`, the fraction of
pixels that must match) and `perPixelTolerance` becomes `perceptualPrecision`
(`1 - perPixelTolerance`, how closely each pixel must match). Because snapshots
are compared as they are captured, the configuration must be supplied to
`DocumentedFlow` rather than only to `generateDocumentation`.

When `deviceFrames` is enabled, each catalog image is composited into a
procedurally-drawn device bezel (rounded body, inset screen, and a Dynamic Island
for notch iPhones) using CoreGraphics — no proprietary device artwork is bundled,
and the per-device geometry is configurable via `DeviceConfiguration.frame`. The
regression snapshots in `__Snapshots__` are left bare; only the copies placed into
the DocC catalog are framed. `organizeByDevice` groups those copies into
per-device subfolders (`Resources/Snapshots/iPhone15Pro/…`); DocC still resolves
the images by filename, so article links are unaffected.

## Using with AI coding agents

If you adopt this library with an AI agent (Claude Code, Cursor, Copilot, …):

* [`AGENTS.md`](AGENTS.md) — a concise integration guide agents read automatically:
  mental model, the canonical test, the run recipe, and a common-mistakes table.
* [`Documentation/AgentSkill/`](Documentation/AgentSkill/) — a reusable Claude Code
  **skill**. Copy the `swift-snapshot-documentation/` folder into your project's
  `.claude/skills/` to give your agent on-demand, invokable guidance.

## Documentation

The documentation for releases and `main` are available here:

* [Swift Snapshot Documentation](https://swiftpackageindex.com/sasha-riabchuk/SwiftSnapshotDocumentation/documentation)

<details>
  <summary>Other documentation</summary>

* Generated DocC catalogs integrate seamlessly with Xcode's documentation viewer
* Each screen generates a dedicated article with device and theme comparisons
* Supports DocC callouts (note, important, warning, tip) for additional context
* Full Markdown support in overview and discussion sections
</details>

## Installation

You can add Swift Snapshot Documentation to an Xcode project by adding it as a package dependency:

1. From the **File** menu, select **Add Package Dependencies...**
2. Enter "https://github.com/sasha-riabchuk/SwiftSnapshotDocumentation" into the package repository URL text field
3. Add the package to your test target

### Swift Package Manager

Add the package as a dependency in your `Package.swift` file:

```swift
dependencies: [
    .package(
        url: "https://github.com/sasha-riabchuk/SwiftSnapshotDocumentation",
        from: "1.0.0"
    )
]
```

Then add it as a dependency of your test target:

```swift
.testTarget(
    name: "YourAppTests",
    dependencies: [
        .product(name: "SwiftSnapshotDocumentation", package: "SwiftSnapshotDocumentation")
    ]
)
```

## Requirements

* iOS 17.0+ / macOS 14.0+
* Swift 5.9+
* Xcode 15.0+

## Other Libraries

Swift Snapshot Documentation depends on:

* [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) 1.15.0+

## Community

For discussions, questions, and announcements:

* **GitHub Discussions**: [Discussions](https://github.com/sasha-riabchuk/SwiftSnapshotDocumentation/discussions)
* **Issue Tracker**: [Report bugs or request features](https://github.com/sasha-riabchuk/SwiftSnapshotDocumentation/issues)

## License

This library is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

* [PointFree](https://www.pointfree.co/) for swift-snapshot-testing
* Apple for DocC and the Swift ecosystem
