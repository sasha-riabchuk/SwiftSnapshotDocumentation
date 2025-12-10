# Example Screenshots

This directory contains example screenshots showcasing the library's capabilities in the main README.

## Recommended Screenshots

To best demonstrate Swift Snapshot Documentation, consider adding:

1. **xcode-docc-viewer.png**: Screenshot of the DocC documentation viewer in Xcode showing the generated documentation catalog
   - Shows the navigation sidebar with article list
   - Displays a sample article with screenshots
   - Demonstrates the native Xcode integration

2. **side-by-side-comparison.png**: Example of light and dark mode comparison
   - Shows the same screen in both light and dark themes side-by-side
   - Demonstrates automatic theme documentation

3. **multiple-devices.png**: Screenshots showing the same screen across different device sizes
   - iPhone SE, iPhone 15 Pro, iPhone 15 Pro Max
   - iPad Pro 11", iPad Pro 12.9"
   - Highlights responsive design documentation

## Image Guidelines

* Use PNG format for screenshots
* Recommended width: 800-1600px for optimal display on GitHub
* Ensure screenshots show realistic app UI (not placeholder content)
* Include descriptive alt text in README references
* Compress images to reduce repository size

## Creating Screenshots

Generate screenshots using the example flow:

```sh
cd SwiftSnapshotDocumentation
swift test --filter ExampleFlowDocumentationTests
open ExampleFlow.docc  # Open in Xcode
# Take screenshots of the Documentation Viewer
```

Then capture Xcode's Documentation Viewer window to showcase the generated output.
