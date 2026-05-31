//
//  SnapshotRecordMode.swift
//  SwiftSnapshotDocumentation
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import SnapshotTesting

/// Controls how a ``DocumentedFlow`` treats snapshots while capturing screens.
///
/// Documentation flows serve two distinct purposes that pull in opposite
/// directions, and this type makes the choice explicit per flow instead of
/// relying on a globally-mutated record flag:
///
/// - **Recording** (re)writes the snapshot images on disk. Run this locally when
///   the UI intentionally changes, then commit the updated snapshots and the
///   regenerated catalog. Recording always reports a test failure (by design, to
///   remind you to review and re-run), so it is not a passing state.
/// - **Verifying** compares the captured screens against the committed snapshots
///   and fails on any difference. This is the regression gate you want on CI.
///
/// - SeeAlso: ``DocumentedFlow/init(name:summary:overview:configuration:record:)``
public enum SnapshotRecordMode: Sendable {
    /// Record (overwrite) every snapshot. Use locally to regenerate baselines + docs.
    case record

    /// Record only snapshots missing from disk; verify the rest. Handy when adding
    /// new screens without disturbing existing baselines.
    case recordMissing

    /// Never record; compare against committed snapshots and fail on any drift.
    /// The appropriate mode for CI.
    case verify

    /// The equivalent swift-snapshot-testing record mode.
    var configuration: SnapshotTestingConfiguration.Record {
        switch self {
        case .record: return .all
        case .recordMissing: return .missing
        case .verify: return .never
        }
    }
}
