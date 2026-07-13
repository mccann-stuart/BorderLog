//
//  DiagnosticsStoreTests.swift
//  LearnTests
//
//  Created by Codex on 11/07/2026.
//

import XCTest
@testable import Learn

@MainActor
final class DiagnosticsStoreTests: XCTestCase {
    func testDiagnosticsPersistAggregateCountsAndTimestamps() async throws {
        let suiteName = "DiagnosticsStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storageKey = "test-diagnostics"
        let store = DiagnosticsStore(defaults: defaults, storageKey: storageKey)
        let startedAt = Date(timeIntervalSince1970: 100)
        let completedAt = Date(timeIntervalSince1970: 200)
        let failedAt = Date(timeIntervalSince1970: 300)
        let recomputedAt = Date(timeIntervalSince1970: 400)

        await store.recordPhotoScanStarted(at: startedAt)
        await store.recordPhotoScanCompleted(
            assetsScanned: 10,
            signalsImported: 3,
            rejectedMissingCreationDate: 1,
            rejectedMissingLocation: 4,
            rejectedDuplicateAsset: 2,
            rejectedUnverifiedCapture: 3,
            unresolvedCountrySignals: 1,
            at: completedAt
        )
        await store.recordPhotoScanFailure(errorCount: 2, at: failedAt)
        await store.recordPhotoGeocodeRetry(
            candidateSignals: 5,
            lookupRequests: 3,
            resolvedSignals: 4,
            unresolvedSignals: 1,
            at: completedAt
        )
        await store.recordPhotoGeocodeRetryFailure(at: failedAt)
        await store.recordSuccessfulRecompute(at: recomputedAt)

        let reloaded = DiagnosticsStore(defaults: defaults, storageKey: storageKey)
        let snapshot = await reloaded.snapshot()

        XCTAssertEqual(snapshot.photoScanning.runsStarted, 1)
        XCTAssertEqual(snapshot.photoScanning.runsCompleted, 1)
        XCTAssertEqual(snapshot.photoScanning.runsFailed, 1)
        XCTAssertEqual(snapshot.photoScanning.assetsScanned, 10)
        XCTAssertEqual(snapshot.photoScanning.signalsImported, 3)
        XCTAssertEqual(snapshot.photoScanning.assetsRejected, 10)
        XCTAssertEqual(snapshot.photoScanning.rejectedMissingCreationDate, 1)
        XCTAssertEqual(snapshot.photoScanning.rejectedMissingLocation, 4)
        XCTAssertEqual(snapshot.photoScanning.rejectedDuplicateAsset, 2)
        XCTAssertEqual(snapshot.photoScanning.rejectedUnverifiedCapture, 3)
        XCTAssertEqual(snapshot.photoScanning.unresolvedCountrySignals, 1)
        XCTAssertEqual(snapshot.photoScanning.errors, 2)
        XCTAssertEqual(snapshot.photoScanning.lastStartedAt, startedAt)
        XCTAssertEqual(snapshot.photoScanning.lastCompletedAt, completedAt)
        XCTAssertEqual(snapshot.photoScanning.lastErrorAt, failedAt)

        XCTAssertEqual(snapshot.photoGeocodeRetries.runsCompleted, 1)
        XCTAssertEqual(snapshot.photoGeocodeRetries.runsFailed, 1)
        XCTAssertEqual(snapshot.photoGeocodeRetries.candidateSignals, 5)
        XCTAssertEqual(snapshot.photoGeocodeRetries.lookupRequests, 3)
        XCTAssertEqual(snapshot.photoGeocodeRetries.resolvedSignals, 4)
        XCTAssertEqual(snapshot.photoGeocodeRetries.unresolvedSignals, 1)
        XCTAssertEqual(snapshot.photoGeocodeRetries.errors, 1)
        XCTAssertEqual(snapshot.lastSuccessfulRecomputeAt, recomputedAt)
    }

    func testBuildCommitUsesValidatedBundleThenEnvironmentAndOtherwiseUnavailable() {
        XCTAssertEqual(
            BuildCommitMetadata.resolvedCommit(
                infoDictionaryValue: "ABCDEF123456",
                environmentValue: "1234567"
            ),
            "abcdef123456"
        )
        XCTAssertEqual(
            BuildCommitMetadata.resolvedCommit(
                infoDictionaryValue: "$(GIT_COMMIT_SHA)",
                environmentValue: "1234567890abcdef"
            ),
            "1234567890abcdef"
        )
        XCTAssertEqual(
            BuildCommitMetadata.resolvedCommit(
                infoDictionaryValue: "",
                environmentValue: "not-a-commit"
            ),
            "unavailable"
        )
    }
}
