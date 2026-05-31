# AGENTS.md

Guidance for AI coding agents integrating **SwiftSnapshotDocumentation** into a project.
(Human contributors: see `CLAUDE.md` for working *on* this library.)

## What this library is

A **test-target** dependency that turns SwiftUI screens into DocC documentation.
You write an XCTest that declares a flow of screens; running it captures
snapshots (via PointFree's swift-snapshot-testing) and emits a `.docc` catalog.
One test both **documents** your UI and **guards** it against regressions.

## Mental model (3 lines)

1. A `DocumentedFlow` is an ordered list of screens you build with `addScreen`.
2. `addScreen` captures a snapshot for every `device × theme` immediately.
3. `generateDocumentation` writes a DocC catalog from those snapshots.

## Integration checklist

1. Add the package **to the test target only** (it imports XCTest and snapshot-testing):
   ```swift
   .testTarget(
       name: "MyAppTests",
       dependencies: [
           .product(name: "SwiftSnapshotDocumentation", package: "SwiftSnapshotDocumentation")
       ]
   )
   ```
   In `dependencies:` of the `Package`:
   ```swift
   .package(url: "https://github.com/sasha-riabchuk/SwiftSnapshotDocumentation", from: "1.0.0")
   ```
2. Write a documentation test (canonical pattern below).
3. **Run on an iOS simulator** — snapshot capture is iOS-only. A plain `swift test`
   on macOS will not capture anything.
4. **Record once, then verify.** First run records baselines; commit them. Later runs
   verify and fail on UI drift.

## Canonical example (compiles as-is)

```swift
import XCTest
import SwiftSnapshotDocumentation
@testable import MyApp

@MainActor
final class OnboardingDocsTests: XCTestCase {
    func testOnboardingDocs() async throws {
        // Verify by default (regression gate); record when RECORD_SNAPSHOTS is set
        // in the scheme/test-plan environment.
        let recording = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil

        let flow = DocumentedFlow(
            name: "Onboarding",
            summary: "New user onboarding",
            overview: "Welcome → Login → Profile.",
            record: recording ? .record : .verify
        )

        await flow.addScreen(
            title: "Welcome",
            description: "Landing screen",
            view: { WelcomeView() },
            devices: [.iPhone15Pro, .iPadPro129],
            themes: [.light, .dark],
            callouts: [.init(type: .tip, content: "Gradient adapts to color scheme")]
        )

        await flow.addScreen(
            title: "Login",
            description: "Authentication",
            view: { LoginView() },
            devices: [.iPhone15Pro],
            themes: [.light, .dark]
        )

        try await flow.generateDocumentation(outputPath: "Onboarding.docc")
    }
}
```

Run it (replace the scheme/destination):
```sh
xcodebuild test \
  -scheme MyAppScheme \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MyAppTests/OnboardingDocsTests
```

## API quick reference

- **`DocumentedFlow(name:summary:overview:configuration:record:)`** — `overview` and
  `configuration` (see below) and `record` are optional.
- **`addScreen(title:description:discussion:view:devices:themes:callouts:)` `async`** —
  `view:` is `() -> some View`; `discussion`/`callouts` optional.
- **`generateDocumentation(outputPath:snapshotSourcePath:configuration:)` `async throws`** —
  writes the `.docc`; throws `DocumentationError` if no snapshots were captured.
- **Devices** (iOS-only): `.iPhoneSE`, `.iPhone15Pro`, `.iPhone15ProMax`, `.iPadPro11`,
  `.iPadPro129`, and `.allIPhones` / `.allIPads` / `.allDevices`.
- **Themes**: `.light`, `.dark`, `.allThemes`.
- **`SnapshotRecordMode`**: `.verify` (CI gate), `.record` (regenerate baselines),
  `.recordMissing` (record only new screens).
- **`Callout`**: `type` is `.note` / `.important` / `.warning` / `.tip` / `.experiment`.
- **`DocumentationConfiguration(imageFormat:deviceFrames:perPixelTolerance:overallTolerance:createIndexPage:includeFlowDiagram:organizeByDevice:)`**
  — pass it to `DocumentedFlow(configuration:)`. Tolerances are applied at capture time.
  `deviceFrames` (default `true`) composites a device bezel onto catalog images.

## Common mistakes (and the fix)

| Symptom | Cause | Fix |
|---|---|---|
| Build error: `has no member 'iPhone15Pro'` on macOS | Capture is iOS-only | Run the test on an iOS **simulator**, not `swift test` on macOS |
| `DocumentationError.noSnapshotsCopied` / `snapshotsNotFound` | No snapshots on disk | Ensure `addScreen` ran in the **same test** before `generateDocumentation`; record first |
| Test fails with "Record mode is on…" | `record: .record` is set | Expected while recording — review and commit the new snapshots, then switch back to `.verify` |
| Verify fails with no reference snapshot | Baselines not committed | Record once (`RECORD_SNAPSHOTS=1`), commit the `__Snapshots__` PNGs |
| Package won't build in the app target | Added to the wrong target | Add it to the **test** target only |
| Docs have broken image links | Capture didn't run (e.g. macOS) | Capture on iOS; generation **throws** if zero images — read the error, it names the fix |

## Notes for agents

- Errors are self-describing: `DocumentationError.description` tells you the corrective
  action. Surface it; don't swallow it.
- Snapshot baselines are tied to the Xcode/simulator they were recorded on; a different
  toolchain may produce diffs in `.verify` mode.
- A reusable Claude Code **skill** is shipped at
  `Documentation/AgentSkill/swift-snapshot-documentation/` — copy that folder into your
  project's `.claude/skills/` to give your agent on-demand, invokable guidance.
