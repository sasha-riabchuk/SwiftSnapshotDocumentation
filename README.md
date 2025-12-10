# Swift Snapshot Documentation

[![CI](https://img.shields.io/github/actions/workflow/status/yourusername/SwiftSnapshotDocumentation/ci.yml?branch=main)](https://github.com/yourusername/SwiftSnapshotDocumentation/actions)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fyourusername%2FSwiftSnapshotDocumentation%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/yourusername/SwiftSnapshotDocumentation)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fyourusername%2FSwiftSnapshotDocumentation%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/yourusername/SwiftSnapshotDocumentation)
[![License](https://img.shields.io/github/license/yourusername/SwiftSnapshotDocumentation)](https://github.com/yourusername/SwiftSnapshotDocumentation/blob/main/LICENSE)

A library for generating beautiful DocC documentation from your SwiftUI screens with automatic snapshot testing across devices and themes.

* [What is Swift Snapshot Documentation?](#what-is-swift-snapshot-documentation)
* [Examples](#examples)
* [Basic Usage](#basic-usage)
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

## Examples

This repo comes with a comprehensive example demonstrating the library's capabilities:

* [**Example Flow**](Tests/ExampleFlowDocumentationTests/): A complete onboarding flow documentation including welcome screens, login forms, and profile states across multiple devices and themes.

Run the example to see the generated DocC catalog:

```sh
cd SwiftSnapshotDocumentation
swift test --filter ExampleFlowDocumentationTests
open ExampleFlow.docc  # View in Xcode
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
    override func setUp() {
        super.setUp()
        isRecording = true  // Set to true to generate/update snapshots
    }

    func testGenerateOnboardingDocs() async throws {
        // Define the flow
        let flow = DocumentedFlow(
            name: "Onboarding",
            summary: "New user onboarding experience",
            overview: """
            Complete onboarding flow from welcome screen to authenticated dashboard.
            This flow introduces new users to the app and guides them through account creation.
            """
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

Run the test to generate documentation:

```sh
swift test --filter OnboardingFlowDocumentation
```

This creates:
- `Documentation.docc/` - DocC catalog with articles for each screen
- `__Snapshots__/` - Snapshot images referenced in the documentation

View the documentation in Xcode by opening `Documentation.docc` or building documentation with Product → Build Documentation (⌃⇧⌘D).

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
    deviceFrames: true,             // Include device bezels in screenshots
    perPixelTolerance: 0.01,        // Snapshot comparison tolerance
    overallTolerance: 0.05,
    createIndexPage: true,          // Generate index page
    organizeByDevice: false         // Group images by device
)

try await flow.generateDocumentation(
    outputPath: "Documentation.docc",
    configuration: config
)
```

## Documentation

The documentation for releases and `main` are available here:

* [Swift Snapshot Documentation](https://swiftpackageindex.com/yourusername/SwiftSnapshotDocumentation/documentation)

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
2. Enter "https://github.com/yourusername/SwiftSnapshotDocumentation" into the package repository URL text field
3. Add the package to your test target

### Swift Package Manager

Add the package as a dependency in your `Package.swift` file:

```swift
dependencies: [
    .package(
        url: "https://github.com/yourusername/SwiftSnapshotDocumentation",
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

* **GitHub Discussions**: [Discussions](https://github.com/yourusername/SwiftSnapshotDocumentation/discussions)
* **Issue Tracker**: [Report bugs or request features](https://github.com/yourusername/SwiftSnapshotDocumentation/issues)

## License

This library is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

* [PointFree](https://www.pointfree.co/) for swift-snapshot-testing
* Apple for DocC and the Swift ecosystem
