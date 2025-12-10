# SwiftSnapshotDocumentation

📸 Generate beautiful DocC documentation from your SwiftUI screens with automatic snapshot testing across devices and themes.

## Overview

SwiftSnapshotDocumentation combines the power of [PointFree's swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) with Apple's DocC to create comprehensive visual documentation for your iOS apps. Perfect for:

- **Design Systems** - Document UI components across themes and devices
- **User Flows** - Visualize complete user journeys with screenshots
- **Code Reviews** - Share visual context without running the app
- **QA/Testing** - Maintain visual regression test coverage
- **Onboarding** - Help new developers understand the app's UI

## Features

✅ **Multiple Devices** - iPhone SE, 15 Pro, 15 Pro Max, iPad Pro 11", 12.9"
✅ **Theme Support** - Automatic light and dark mode screenshots
✅ **DocC Integration** - Native Xcode documentation viewer support
✅ **PointFree Powered** - Built on battle-tested snapshot-testing library
✅ **Flow-Based** - Document complete user journeys, not just screens
✅ **Rich Documentation** - Markdown, callouts, cross-references
✅ **CI/CD Ready** - Detect visual regressions in your pipeline

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftSnapshotDocumentation", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter repository URL
3. Add to your test target

## Quick Start

### 1. Create a Documentation Test

```swift
import XCTest
import SwiftSnapshotDocumentation
@testable import YourApp

@MainActor
final class OnboardingFlowDocumentation: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = true  // Generate snapshots
    }

    func testGenerateOnboardingDocs() async throws {
        let flow = DocumentedFlow(
            name: "Onboarding",
            summary: "New user onboarding experience",
            overview: "Complete onboarding flow from welcome to dashboard."
        )

        // Document each screen
        await flow.addScreen(
            title: "Welcome Screen",
            description: "App introduction",
            view: { WelcomeView() },
            devices: [.iPhone15Pro, .iPadPro129],
            themes: [.light, .dark]
        )

        await flow.addScreen(
            title: "Login Screen",
            description: "User authentication",
            view: { LoginView() },
            devices: [.iPhone15Pro],
            themes: [.light, .dark],
            callouts: [
                .init(type: .important, content: "Supports biometric authentication")
            ]
        )

        // Generate DocC catalog
        try await flow.generateDocumentation(
            outputPath: "Sources/YourModule/Documentation.docc"
        )
    }
}
```

### 2. Run the Test

```bash
# Generate/update snapshots
swift test

# The test will create:
# - Documentation.docc/ (DocC catalog)
# - __Snapshots__/ (snapshot images)
```

### 3. View Documentation

**In Xcode:**
- Open `Documentation.docc` in Xcode
- Product → Build Documentation (⌃⇧⌘D)
- View in Documentation Viewer

**Or build manually:**
```bash
xcodebuild docbuild \
  -scheme YourScheme \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## API Reference

### DocumentedFlow

The main container for your documentation:

```swift
let flow = DocumentedFlow(
    name: "Feature Name",
    summary: "Brief description",
    overview: """
    Extended Markdown overview with:
    - Lists
    - **Bold** and *italic*
    - Code blocks
    - Links
    """
)
```

### Adding Screens

```swift
await flow.addScreen(
    title: "Screen Title",
    description: "Brief description",
    discussion: "Optional extended discussion in Markdown",
    view: { YourSwiftUIView() },
    devices: [.iPhone15Pro, .iPadPro129],
    themes: [.light, .dark],
    callouts: [
        .init(type: .note, content: "Additional info"),
        .init(type: .important, content: "Critical detail"),
        .init(type: .warning, content: "Potential issue"),
        .init(type: .tip, content: "Helpful suggestion")
    ]
)
```

### Device Configurations

```swift
// Individual devices
.iPhoneSE
.iPhone15Pro
.iPhone15ProMax
.iPadPro11
.iPadPro129

// Collections
.allIPhones  // All iPhone sizes
.allIPads    // All iPad sizes
.allDevices  // Everything
```

### Theme Configurations

```swift
.light       // Light mode
.dark        // Dark mode
.allThemes   // Both light and dark
```

### Documentation Configuration

```swift
let config = DocumentationConfiguration(
    imageFormat: .png,              // or .jpeg
    deviceFrames: true,             // Include device bezels
    perPixelTolerance: 0.01,        // Snapshot comparison tolerance
    overallTolerance: 0.05,
    createIndexPage: true,          // Generate main page
    includeFlowDiagram: false,      // Future: Mermaid diagrams
    organizeByDevice: false         // Group images by device
)

try await flow.generateDocumentation(
    outputPath: "Documentation.docc",
    configuration: config
)
```

## Example Output

The generated DocC catalog includes:

```
Documentation.docc/
├── YourFlow.md                     # Main catalog file
├── 01-welcome-screen.md            # Screen articles
├── 02-login-screen.md
├── 03-profile-form.md
└── Resources/
    └── Snapshots/
        ├── 01-welcome-screen-iphone15pro-light.png
        ├── 01-welcome-screen-iphone15pro-dark.png
        ├── 01-welcome-screen-ipadpro129-light.png
        └── ...
```

Each article shows:
- Side-by-side light/dark mode comparison
- Multiple device sizes
- Rich Markdown documentation
- Callouts and notes
- Navigation between screens

## Advanced Usage

### Multiple States

Document different view states:

```swift
// Empty state
await flow.addScreen(
    title: "Profile - Empty",
    description: "No data entered",
    view: { ProfileView(data: nil) },
    devices: [.iPhone15Pro],
    themes: [.light]
)

// Filled state
await flow.addScreen(
    title: "Profile - Filled",
    description: "With user data",
    view: { ProfileView(data: mockData) },
    devices: [.iPhone15Pro],
    themes: [.light]
)

// Loading state
await flow.addScreen(
    title: "Profile - Loading",
    description: "Saving data",
    view: { ProfileView(data: mockData, isLoading: true) },
    devices: [.iPhone15Pro],
    themes: [.light]
)
```

### CI/CD Integration

```yaml
# .github/workflows/documentation.yml
name: Generate Documentation

on: [pull_request]

jobs:
  docs:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Generate Documentation
        run: |
          swift test --filter DocumentationTests

      - name: Check for Visual Regressions
        run: |
          # Set isRecording = false to verify snapshots
          # Test will fail if UI changed
          swift test --filter DocumentationTests

      - name: Upload Documentation
        uses: actions/upload-artifact@v3
        with:
          name: documentation
          path: '**/*.docc'
```

## Example Project

See `Tests/ExampleFlowDocumentationTests/` for a complete working example with:
- Welcome screen
- Login form
- Profile form (empty, filled, loading states)
- Complete DocC documentation

Run the example:

```bash
cd SwiftSnapshotDocumentation
swift test --filter ExampleFlowDocumentationTests
open ExampleFlow.docc  # View in Xcode
```

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 5.9+
- Xcode 15.0+

## Dependencies

- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) 1.15.0+

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## License

MIT License - see LICENSE file for details

## Acknowledgments

- [PointFree](https://www.pointfree.co/) for swift-snapshot-testing
- Apple for DocC
- The Swift community

## Support

- 📖 [Documentation](./Documentation)
- 🐛 [Issues](https://github.com/yourusername/SwiftSnapshotDocumentation/issues)
- 💬 [Discussions](https://github.com/yourusername/SwiftSnapshotDocumentation/discussions)

---
