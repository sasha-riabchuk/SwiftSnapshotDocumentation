# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this package does

A Swift library that combines PointFree's [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) with Apple's DocC. You write an XCTest that declares a user flow of SwiftUI screens; running the test captures device/theme snapshots and emits a `.docc` catalog (Markdown articles + copied images) you can open in Xcode's documentation viewer. It is meant to be consumed as a **test-target dependency** of an app, not run in production.

## Build & test commands

```sh
swift build                                    # build the library + examples
swift test                                     # run all tests
swift test --filter SwiftSnapshotDocumentationTests   # unit tests only
swift test --filter ExampleFlowDocumentationTests     # generates ExampleFlow.docc
swift test --filter ExampleFlowDocumentationTests/testGenerateExampleFlowDocumentation  # single test
```

**Critical: snapshot capture is iOS-only.** `captureSnapshot` in `DocumentedFlow.swift` is wrapped in `#if os(iOS)`; on macOS it just prints a warning and produces no images. To actually generate documentation with screenshots you must run the tests on an **iOS simulator**, e.g.:

```sh
xcodebuild test -scheme SwiftSnapshotDocumentation \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:ExampleFlowDocumentationTests
```

Note: `swift test` on the Mac does **not even build** — `ExampleFlowDocumentationTests` references iOS-only device constants (`.iPhone15Pro`, etc., gated behind `#if os(iOS)`) unconditionally, so the whole test build fails for macOS. Run the test suite via `xcodebuild test ... -destination 'platform=iOS Simulator,...'`. Boot a simulator first (`xcrun simctl boot <id>`) if `xcodebuild` reports "Invalid connectionUUID". The pure-logic unit tests live in `SwiftSnapshotDocumentationTests` and can be run in isolation with `-only-testing:SwiftSnapshotDocumentationTests`.

## Recording vs. verifying

Snapshots have two modes, toggled by `isRecording` (set in the test's `setUp`):
- `isRecording = true` — captures/overwrites snapshot PNGs (needed to regenerate docs). The example test and README examples ship with this **on**.
- `isRecording = false` — compares against committed snapshots and fails on diff (CI/regression mode).

Snapshots land in `__Snapshots__/<TestClass>/` next to the test file (created by swift-snapshot-testing), with filenames prefixed by the test function name.

## Architecture

The public API is a small builder + an internal generator, split into `Core/` and `Models/`:

- **`DocumentedFlow`** (`Core/`, `@MainActor`) — the entry point. `addScreen(...)` is the core method: it appends a `DocumentedScreen` and immediately loops every device×theme combination calling `captureSnapshot`. `generateDocumentation(...)` hands off to `DoCCGenerator`. Note `addScreen` captures snapshots eagerly as it's called, while doc generation happens later — so screen order in the file is the order in the docs.

- **`DoCCGenerator`** (`Core/`, internal) — pure file-writing. Creates the `.docc` directory tree, **copies** images out of `__Snapshots__` into `Resources/Snapshots/` (stripping the `testName.` filename prefix, anchored on the `NN-` identifier), then writes the main catalog `.md` (with `@TechnologyRoot`/`@PageKind`) and one numbered article per screen (`01-<id>.md`, …) with light/dark side-by-side tables and prev/next/up navigation. The snapshot source dir is resolved deterministically from the test's `#file` (via `DocumentedFlow.snapshotDirectory(forFile:)`), not guessed from the working directory. Generation **throws** `DocumentationError` if no snapshots are found or none are copied, rather than silently emitting a catalog with broken image links — so the image copy happens before any Markdown is written.

- **Models** — value types describing the inputs:
  - `DocumentedScreen` — title/description/discussion/callouts + the `() -> any View` builder. `id` is derived from the title via `sanitizedForFilename()` (lowercased, hyphenated) unless given. Defines the nested `Callout` (`.note/.important/.warning/.tip/.experiment`).
  - `DeviceConfiguration` — wraps a swift-snapshot-testing `ViewImageConfig`. Predefined devices + `allIPhones`/`allIPads`/`allDevices`. **iOS-only static members** (also under `#if os(iOS)`); equality/hashing key on `name`.
  - `ThemeConfiguration` — `.light`/`.dark`/`allThemes`, maps to a SwiftUI `ColorScheme`.
  - `DocumentationConfiguration` — generation options (image format, tolerances, index page, etc.). Some flags (`deviceFrames`, `includeFlowDiagram`, `organizeByDevice`) are declared but not yet fully wired into the generator.

The **snapshot filename contract** is the coupling point between the two halves: `DocumentedFlow.captureSnapshot` formats names as `%02d-<screen.id>-<device.name>-<theme.name>`, and `DoCCGenerator.snapshotFilename` must produce the identical string (plus extension) for the Markdown image links to resolve. Changing the naming in one place requires changing the other.

## Targets

- `SwiftSnapshotDocumentation` — the library (the only published product).
- `SwiftSnapshotDocumentationExamples` — sample SwiftUI views (`WelcomeExampleView`, `LoginExampleView`, `ProfileFormExampleView`) used by the example test.
- `SwiftSnapshotDocumentationTests` — unit tests for the library.
- `ExampleFlowDocumentationTests` — end-to-end test that actually generates a DocC catalog; the canonical usage example.

## Platform requirements

iOS 17+ / macOS 14+, Swift 5.9+ (tools-version 5.9). Public symbols that depend on UIKit/snapshot config are gated behind `#if os(iOS)` / `@available(iOS 17.0, *)` — preserve this gating when adding device-related API so the package keeps building on macOS.
