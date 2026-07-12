//
//  PhotoSignalGeocodeRetryServiceTests.swift
//  LearnTests
//
//  Created by Codex on 11/07/2026.
//

import CoreLocation
import SwiftData
import XCTest
@testable import Learn

private struct RetryStubCountryResolver: CountryResolving {
    func resolveCountry(for location: CLLocation) async -> CountryResolution? {
        guard location.coordinate.latitude == 35.6762 else { return nil }
        return CountryResolution(
            countryCode: "JP",
            countryName: "Japan",
            timeZone: TimeZone(identifier: "Asia/Tokyo")
        )
    }
}

@MainActor
final class PhotoSignalGeocodeRetryServiceTests: XCTestCase {
    func testRetryResolvesCoordinateGroupAndReturnsOldAndNewDayKeys() async throws {
        let suiteName = "PhotoSignalGeocodeRetryServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let recoveryStore = LedgerRecomputeRecoveryStore(defaults: defaults)
        let diagnosticsStore = DiagnosticsStore(defaults: defaults, storageKey: "retry-diagnostics")
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PhotoSignal.self, configurations: configuration)
        let context = container.mainContext
        let timestamp = Date(timeIntervalSince1970: 1_772_407_800) // 2026-03-01 23:30 UTC

        for hash in ["tokyo-1", "tokyo-2"] {
            context.insert(
                PhotoSignal(
                    timestamp: timestamp,
                    latitude: 35.6762,
                    longitude: 139.6503,
                    assetIdHash: hash,
                    timeZoneId: "UTC",
                    dayKey: "2026-03-01",
                    countryCode: nil,
                    countryName: nil
                )
            )
        }
        context.insert(
            PhotoSignal(
                timestamp: timestamp,
                latitude: 0,
                longitude: 0,
                assetIdHash: "still-unresolved",
                timeZoneId: "UTC",
                dayKey: "2026-03-01",
                countryCode: nil,
                countryName: nil
            )
        )
        context.insert(
            PhotoSignal(
                timestamp: timestamp,
                latitude: 51.5074,
                longitude: -0.1278,
                assetIdHash: "already-resolved",
                timeZoneId: "Europe/London",
                dayKey: "2026-03-01",
                countryCode: "GB",
                countryName: "United Kingdom"
            )
        )
        try context.save()

        let service = PhotoSignalGeocodeRetryService(
            modelContainer: container,
            resolver: RetryStubCountryResolver(),
            recoveryStore: recoveryStore,
            diagnosticsStore: diagnosticsStore
        )
        let result = try await service.retryUnresolved()

        XCTAssertEqual(result.stats.candidateSignals, 3)
        XCTAssertEqual(result.stats.lookupRequests, 2)
        XCTAssertEqual(result.stats.resolvedSignals, 2)
        XCTAssertEqual(result.stats.unresolvedSignals, 1)
        XCTAssertEqual(result.stats.errors, 0)
        XCTAssertEqual(result.touchedDayKeys, Set(["2026-03-01", "2026-03-02"]))
        XCTAssertEqual(recoveryStore.dirtyDayKeys(), result.touchedDayKeys)

        let diagnostics = await diagnosticsStore.snapshot()
        XCTAssertEqual(diagnostics.photoGeocodeRetries.runsCompleted, 1)
        XCTAssertEqual(diagnostics.photoGeocodeRetries.candidateSignals, 3)
        XCTAssertEqual(diagnostics.photoGeocodeRetries.lookupRequests, 2)
        XCTAssertEqual(diagnostics.photoGeocodeRetries.resolvedSignals, 2)
        XCTAssertEqual(diagnostics.photoGeocodeRetries.unresolvedSignals, 1)

        let verificationContext = ModelContext(container)
        let signals = try verificationContext.fetch(FetchDescriptor<PhotoSignal>())
        let tokyoSignals = signals.filter { $0.assetIdHash.hasPrefix("tokyo-") }
        XCTAssertEqual(tokyoSignals.count, 2)
        XCTAssertTrue(tokyoSignals.allSatisfy { $0.countryCode == "JP" })
        XCTAssertTrue(tokyoSignals.allSatisfy { $0.countryName == "Japan" })
        XCTAssertTrue(tokyoSignals.allSatisfy { $0.timeZoneId == "Asia/Tokyo" })
        XCTAssertTrue(tokyoSignals.allSatisfy { $0.dayKey == "2026-03-02" })

        let unresolved = try XCTUnwrap(signals.first { $0.assetIdHash == "still-unresolved" })
        XCTAssertNil(unresolved.countryCode)
        XCTAssertNil(unresolved.countryName)
        XCTAssertEqual(unresolved.dayKey, "2026-03-01")
    }
}
