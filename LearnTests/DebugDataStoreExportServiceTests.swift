//
//  DebugDataStoreExportServiceTests.swift
//  LearnTests
//
//  Created by Codex on 21/03/2026.
//

import XCTest
@testable import Learn
import SwiftData

@MainActor
final class DebugDataStoreExportServiceTests: XCTestCase {
    private let utc = TimeZone(secondsFromGMT: 0) ?? .current

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Stay.self,
            DayOverride.self,
            LocationSample.self,
            PhotoSignal.self,
            CalendarSignal.self,
            PresenceDay.self,
            PhotoIngestState.self,
            CountryConfig.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? Date()
    }

    private func makeRuntimeContext(exportedAt: Date) -> DebugExportRuntimeContext {
        DebugExportRuntimeContext(
            metadata: DebugExportMetadata(
                exportedAt: exportedAt,
                appVersion: "1.2.3",
                appBuild: "456",
                bundleIdentifier: "com.example.BorderLog",
                deviceModelCategory: "phone",
                operatingSystemVersion: "Version 26.0",
                localeIdentifier: "en_GB",
                currentTimeZoneId: utc.identifier,
                appVariantFlags: DebugExportAppVariantFlags(
                    cloudKitFeatureEnabled: false,
                    appleSignInEnabled: false,
                    appGroupAvailable: true
                )
            ),
            appState: DebugExportAppState(
                hasCompletedOnboarding: true,
                didBootstrapInference: true,
                hasPromptedLocation: true,
                hasPromptedPhotos: true,
                hasPromptedCalendar: false,
                usePolygonMapView: true,
                showSchengenDashboardSection: true,
                cloudKitSyncEnabled: false,
                requireBiometrics: true,
                locationPermission: DebugExportPermissionStatus(rawValue: 4, label: "Always On"),
                photoPermission: DebugExportPermissionStatus(rawValue: 3, label: "Geo Location Access"),
                calendarPermission: DebugExportPermissionStatus(rawValue: 2, label: "Read Access"),
                dataStoreMode: "local",
                appGroupAvailable: true,
                cloudKitFeatureEnabled: false,
                currentStoreEpoch: 6,
                storedStoreEpoch: 6,
                widgetLastWriteDate: makeDate(2026, 3, 4, hour: 8),
                pendingWidgetSnapshotCount: 1
            ),
            userData: DebugExportUserData(
                passportNationality: "GB",
                homeCountry: "GB",
                appleUserId: nil,
                appleSignInEnabled: false
            ),
            pendingLocationSnapshots: [
                DebugExportPendingLocationSnapshot(
                    timestamp: makeDate(2026, 3, 7, hour: 9, minute: 15),
                    latitude: 48.8566,
                    longitude: 2.3522,
                    accuracyMeters: 12,
                    sourceRaw: LocationSampleSource.widget.rawValue,
                    timeZoneId: utc.identifier,
                    dayKey: "2026-03-07",
                    countryCode: "FR",
                    countryName: "France"
                )
            ]
        )
    }

    private func seedData(in container: ModelContainer) throws {
        let context = container.mainContext
        let dayTimeZoneId = utc.identifier

        context.insert(
            Stay(
                countryName: "France",
                countryCode: "FR",
                dayTimeZoneId: dayTimeZoneId,
                entryDayKey: "2026-03-01",
                exitDayKey: "2026-03-03",
                region: .schengen,
                enteredOn: makeDate(2026, 3, 1),
                exitedOn: makeDate(2026, 3, 3),
                notes: "Paris work trip"
            )
        )

        context.insert(
            DayOverride(
                date: makeDate(2026, 3, 2),
                countryName: "United Kingdom",
                countryCode: "GB",
                dayKey: "2026-03-02",
                dayTimeZoneId: dayTimeZoneId,
                region: .nonSchengen,
                notes: "Manual correction"
            )
        )

        context.insert(
            LocationSample(
                timestamp: makeDate(2026, 3, 4, hour: 8),
                latitude: 51.5074,
                longitude: -0.1278,
                accuracyMeters: 25,
                source: .widget,
                timeZoneId: dayTimeZoneId,
                dayKey: "2026-03-04",
                countryCode: "GB",
                countryName: "United Kingdom"
            )
        )

        context.insert(
            LocationSample(
                timestamp: makeDate(2026, 3, 8, hour: 18),
                latitude: 40.4168,
                longitude: -3.7038,
                accuracyMeters: 14,
                source: .app,
                timeZoneId: dayTimeZoneId,
                dayKey: "2026-03-08",
                countryCode: "ES",
                countryName: "Spain"
            )
        )

        context.insert(
            PhotoSignal(
                timestamp: makeDate(2026, 3, 4, hour: 12),
                latitude: 51.5000,
                longitude: -0.1200,
                assetIdHash: "asset-raw-1",
                timeZoneId: dayTimeZoneId,
                dayKey: "2026-03-04",
                countryCode: "GB",
                countryName: "United Kingdom"
            )
        )

        context.insert(
            CalendarSignal(
                timestamp: makeDate(2026, 3, 4, hour: 16),
                dayKey: "2026-03-04",
                latitude: 51.4700,
                longitude: -0.4543,
                countryCode: "GB",
                countryName: "United Kingdom",
                timeZoneId: dayTimeZoneId,
                bucketingTimeZoneId: dayTimeZoneId,
                eventIdentifier: "evt-flight-1",
                title: "BA 123 LHR",
                source: "Calendar"
            )
        )

        context.insert(
            PresenceDay(
                dayKey: "2026-03-01",
                date: makeDate(2026, 3, 1),
                timeZoneId: dayTimeZoneId,
                contributedCountries: [
                    ContributedCountry(countryCode: "FR", countryName: "France", probability: 0.7),
                    ContributedCountry(countryCode: "DE", countryName: "Germany", probability: 0.3)
                ],
                zoneOverlays: ["Schengen"],
                evidence: [
                    SignalImpact(source: "stay", countryCode: "FR", countryName: "France", scoreDelta: 1.4),
                    SignalImpact(source: "photo", countryCode: "FR", countryName: "France", scoreDelta: 0.8)
                ],
                confidence: 0.91,
                confidenceLabel: .high,
                sources: [.stay, .photo],
                isOverride: false,
                stayCount: 1,
                photoCount: 2,
                locationCount: 0,
                calendarCount: 1,
                isDisputed: true,
                suggestedCountryCode1: "ES",
                suggestedCountryName1: "Spain",
                suggestedCountryCode2: "BE",
                suggestedCountryName2: "Belgium"
            )
        )

        context.insert(
            PresenceDay(
                dayKey: "2026-03-06",
                date: makeDate(2026, 3, 6),
                timeZoneId: dayTimeZoneId,
                contributedCountries: [],
                zoneOverlays: [],
                evidence: [],
                confidence: 0.05,
                confidenceLabel: .low,
                sources: [],
                isOverride: false,
                stayCount: 0,
                photoCount: 0,
                locationCount: 0,
                calendarCount: 0
            )
        )

        context.insert(CountryConfig(countryCode: "FR", maxAllowedDays: 90))
        context.insert(
            PhotoIngestState(
                lastIngestedAt: makeDate(2026, 3, 5, hour: 10),
                lastAssetCreationDate: makeDate(2026, 3, 4, hour: 12),
                lastAssetIdHash: "asset-last",
                fullScanCompleted: true,
                lastFullScanAt: makeDate(2026, 3, 5, hour: 10, minute: 30)
            )
        )

        try context.save()
    }

    func testBuildPayloadIncludesRuntimeContextAndSummary() async throws {
        let container = try makeContainer()
        try seedData(in: container)
        let exportedAt = makeDate(2026, 3, 10, hour: 9, minute: 30)
        let runtimeContext = makeRuntimeContext(exportedAt: exportedAt)

        let service = DebugDataStoreExportService(modelContainer: container)
        let payload = try await service.buildPayload(context: runtimeContext)

        XCTAssertEqual(payload.metadata.appVersion, "1.2.3")
        XCTAssertEqual(payload.metadata.appBuild, "456")
        XCTAssertEqual(payload.metadata.deviceModelCategory, "phone")
        XCTAssertEqual(payload.appState.dataStoreMode, "local")
        XCTAssertEqual(payload.appState.pendingWidgetSnapshotCount, 1)
        XCTAssertEqual(payload.userData.passportNationality, "GB")
        XCTAssertNil(payload.userData.appleUserId)

        XCTAssertEqual(payload.summary.recordCounts.stays, 1)
        XCTAssertEqual(payload.summary.recordCounts.dayOverrides, 1)
        XCTAssertEqual(payload.summary.recordCounts.locationSamples, 2)
        XCTAssertEqual(payload.summary.recordCounts.photoSignals, 1)
        XCTAssertEqual(payload.summary.recordCounts.calendarSignals, 1)
        XCTAssertEqual(payload.summary.recordCounts.presenceDays, 2)
        XCTAssertEqual(payload.summary.recordCounts.countryConfigs, 1)
        XCTAssertEqual(payload.summary.recordCounts.photoIngestStates, 1)
        XCTAssertEqual(payload.summary.recordCounts.pendingLocationSnapshots, 1)

        XCTAssertEqual(payload.summary.dateBounds.stays?.earliest, makeDate(2026, 3, 1))
        XCTAssertEqual(payload.summary.dateBounds.stays?.latest, makeDate(2026, 3, 1))
        XCTAssertEqual(payload.summary.dateBounds.locationSamples?.earliest, makeDate(2026, 3, 4, hour: 8))
        XCTAssertEqual(payload.summary.dateBounds.locationSamples?.latest, makeDate(2026, 3, 8, hour: 18))
        XCTAssertEqual(payload.summary.dateBounds.photoIngestActivity?.earliest, makeDate(2026, 3, 4, hour: 12))
        XCTAssertEqual(payload.summary.dateBounds.photoIngestActivity?.latest, makeDate(2026, 3, 5, hour: 10, minute: 30))

        XCTAssertEqual(payload.summary.presenceDayTotals.unknown, 1)
        XCTAssertEqual(payload.summary.presenceDayTotals.disputed, 1)
        XCTAssertEqual(payload.summary.presenceDayTotals.manual, 1)

        XCTAssertEqual(payload.summary.sourceTotals.appLocationSamples, 1)
        XCTAssertEqual(payload.summary.sourceTotals.widgetLocationSamples, 1)
        XCTAssertEqual(payload.summary.sourceTotals.presenceDaysWithStaySource, 1)
        XCTAssertEqual(payload.summary.sourceTotals.presenceDaysWithPhotoSource, 1)

        XCTAssertEqual(payload.summary.schengenLedgerSummary.usedDays, 1)
        XCTAssertEqual(payload.summary.schengenLedgerSummary.remainingDays, 89)
    }

    func testBuildPayloadBuildsDeterministicDayUnionAndPreservesDiagnostics() async throws {
        let container = try makeContainer()
        try seedData(in: container)
        let runtimeContext = makeRuntimeContext(exportedAt: makeDate(2026, 3, 10, hour: 9, minute: 30))

        let service = DebugDataStoreExportService(modelContainer: container)
        let payload = try await service.buildPayload(context: runtimeContext)

        XCTAssertEqual(payload.days.map(\.dayKey), [
            "2026-03-01",
            "2026-03-02",
            "2026-03-03",
            "2026-03-04",
            "2026-03-06",
            "2026-03-08"
        ])

        let march1 = try XCTUnwrap(payload.days.first { $0.dayKey == "2026-03-01" })
        XCTAssertEqual(march1.presence?.countryCode, "FR")
        XCTAssertEqual(march1.presence?.sourceLabels, ["stay", "photo"])
        XCTAssertEqual(march1.presence?.suggestedCountryCode1, "ES")
        XCTAssertEqual(march1.presence?.suggestedCountryCode2, "BE")
        XCTAssertEqual(march1.presenceSummary?.countryCode, "FR")
        XCTAssertEqual(march1.presenceSummary?.countryName, "France")
        XCTAssertEqual(march1.presenceSummary?.suggestedCountryCode1, "ES")
        XCTAssertEqual(march1.presenceSummary?.suggestedCountryCode2, "BE")
        XCTAssertEqual(march1.presenceSummary?.sourceLabels, ["stay", "photo"])
        XCTAssertEqual(march1.presenceSummary?.confidence, 0.91, accuracy: 0.0001)
        XCTAssertEqual(march1.presenceSummary?.confidenceLabelRaw, "high")
        XCTAssertEqual(march1.presenceSummary?.isDisputed, true)
        XCTAssertEqual(march1.presenceSummary?.isManuallyModified, true)
        XCTAssertEqual(march1.staysCoveringDay.count, 1)
        XCTAssertTrue(march1.hasAnyRawEvidence)

        let march2 = try XCTUnwrap(payload.days.first { $0.dayKey == "2026-03-02" })
        XCTAssertEqual(march2.dayOverride?.countryCode, "GB")
        XCTAssertEqual(march2.staysCoveringDay.count, 1)
        XCTAssertEqual(march2.sourceCounts.overrides, 1)

        let march3 = try XCTUnwrap(payload.days.first { $0.dayKey == "2026-03-03" })
        XCTAssertNil(march3.presence)
        XCTAssertNil(march3.presenceSummary)
        XCTAssertNil(march3.dayOverride)
        XCTAssertEqual(march3.staysCoveringDay.count, 1)
        XCTAssertEqual(march3.sourceCounts.stays, 1)
        XCTAssertTrue(march3.hasAnyRawEvidence)

        let march4 = try XCTUnwrap(payload.days.first { $0.dayKey == "2026-03-04" })
        XCTAssertEqual(march4.locations.count, 1)
        XCTAssertEqual(march4.photos.count, 1)
        XCTAssertEqual(march4.calendarSignals.count, 1)
        XCTAssertEqual(march4.calendarSignals.first?.eventIdentifier, "evt-flight-1")
        XCTAssertEqual(march4.calendarSignals.first?.title, "BA 123 LHR")
        XCTAssertEqual(march4.photos.first?.assetIdHash, "asset-raw-1")
        XCTAssertEqual(march4.locations.first?.latitude, 51.5074, accuracy: 0.0001)
        XCTAssertEqual(march4.sourceCounts.calendarSignals, 1)
        XCTAssertTrue(march4.hasAnyRawEvidence)
    }

    func testExportJSONProducesValidJsonAndKeepsFullFidelityFields() async throws {
        let container = try makeContainer()
        try seedData(in: container)
        let exportedAt = makeDate(2026, 3, 10, hour: 9, minute: 30)
        let runtimeContext = makeRuntimeContext(exportedAt: exportedAt)

        let service = DebugDataStoreExportService(modelContainer: container)
        let data = try await service.exportJSON(context: runtimeContext)

        let jsonObject = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(jsonObject.keys), Set(["appState", "days", "metadata", "records", "summary", "userData"]))

        let metadata = try XCTUnwrap(jsonObject["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["exportedAt"] as? String, "2026-03-10T09:30:00.000Z")

        let records = try XCTUnwrap(jsonObject["records"] as? [String: Any])
        let calendarSignals = try XCTUnwrap(records["calendarSignals"] as? [[String: Any]])
        XCTAssertEqual(calendarSignals.first?["eventIdentifier"] as? String, "evt-flight-1")
        XCTAssertEqual(calendarSignals.first?["title"] as? String, "BA 123 LHR")

        let photoSignals = try XCTUnwrap(records["photoSignals"] as? [[String: Any]])
        XCTAssertEqual(photoSignals.first?["assetIdHash"] as? String, "asset-raw-1")

        let locationSamples = try XCTUnwrap(records["locationSamples"] as? [[String: Any]])
        let latitude = try XCTUnwrap(locationSamples.first?["latitude"] as? Double)
        let longitude = try XCTUnwrap(locationSamples.first?["longitude"] as? Double)
        XCTAssertEqual(latitude, 51.5074, accuracy: 0.0001)
        XCTAssertEqual(longitude, -0.1278, accuracy: 0.0001)

        let userData = try XCTUnwrap(jsonObject["userData"] as? [String: Any])
        XCTAssertEqual(userData["passportNationality"] as? String, "GB")
        XCTAssertTrue(userData.keys.contains("appleUserId"))
        XCTAssertTrue(userData["appleUserId"] is NSNull)

        let days = try XCTUnwrap(jsonObject["days"] as? [[String: Any]])
        let march1 = try XCTUnwrap(days.first { ($0["dayKey"] as? String) == "2026-03-01" })
        let presenceSummary = try XCTUnwrap(march1["presenceSummary"] as? [String: Any])
        XCTAssertEqual(presenceSummary["countryCode"] as? String, "FR")
        XCTAssertEqual(presenceSummary["countryName"] as? String, "France")
        XCTAssertEqual(presenceSummary["suggestedCountryCode1"] as? String, "ES")
        XCTAssertEqual(presenceSummary["suggestedCountryCode2"] as? String, "BE")
        XCTAssertEqual(presenceSummary["confidenceLabelRaw"] as? String, "high")
    }
}
