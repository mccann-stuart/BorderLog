//
//  CalendarTabDataServiceTests.swift
//  LearnTests
//
//  Created by Codex on 19/03/2026.
//

import XCTest
@testable import Learn
import SwiftData

@MainActor
final class CalendarTabDataServiceTests: XCTestCase {
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
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    private func normalizedDate(for dayKey: String, timeZone: TimeZone = .current) -> Date {
        DayKey.date(for: dayKey, timeZone: timeZone) ?? Date()
    }

    func testSnapshotDedupesCountriesPerDayAndMarksFlights() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dayKey = "2026-03-19"
        let timeZoneID = TimeZone.current.identifier

        context.insert(
            LocationSample(
                timestamp: makeDate(2026, 3, 19, hour: 8),
                latitude: 40.7128,
                longitude: -74.0060,
                accuracyMeters: 35,
                source: .app,
                timeZoneId: timeZoneID,
                dayKey: dayKey,
                countryCode: "US",
                countryName: "United States"
            )
        )
        context.insert(
            PhotoSignal(
                timestamp: makeDate(2026, 3, 19, hour: 14),
                latitude: 40.7128,
                longitude: -74.0060,
                assetIdHash: "asset-1",
                timeZoneId: timeZoneID,
                dayKey: dayKey,
                countryCode: "US",
                countryName: "United States"
            )
        )
        context.insert(
            CalendarSignal(
                timestamp: makeDate(2026, 3, 19, hour: 18),
                dayKey: dayKey,
                latitude: 51.5074,
                longitude: -0.1278,
                countryCode: "GB",
                countryName: "United Kingdom",
                timeZoneId: timeZoneID,
                bucketingTimeZoneId: timeZoneID,
                eventIdentifier: "flight-1",
                title: "Flight to London",
                source: "Calendar"
            )
        )
        context.insert(CountryConfig(countryCode: "GB", maxAllowedDays: 180))
        try context.save()

        let service = CalendarTabDataService(modelContainer: container)
        let snapshot = try await service.snapshot(
            visibleMonthStart: makeDate(2026, 3, 1),
            summaryRange: .visibleMonth,
            now: makeDate(2026, 3, 19)
        )

        XCTAssertEqual(snapshot.daySummaries.count, 31)

        let march19 = try XCTUnwrap(snapshot.daySummaries.first { $0.dayKey == dayKey })
        XCTAssertTrue(march19.hasFlight)
        XCTAssertEqual(Set(march19.countries.map(\.id)), Set(["US", "GB"]))

        let totals = Dictionary(uniqueKeysWithValues: snapshot.countrySummaries.map { ($0.id, $0) })
        XCTAssertEqual(totals["US"]?.totalDays, 1)
        XCTAssertEqual(totals["GB"]?.totalDays, 1)
        XCTAssertEqual(totals["GB"]?.maxAllowedDays, 180)
    }

    func testSnapshotExpandsStaysAcrossMonthBoundaries() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let timeZoneID = TimeZone.current.identifier

        context.insert(
            Stay(
                countryName: "France",
                countryCode: "FR",
                dayTimeZoneId: timeZoneID,
                entryDayKey: "2026-02-28",
                exitDayKey: "2026-03-02",
                region: .schengen,
                enteredOn: normalizedDate(for: "2026-02-28"),
                exitedOn: normalizedDate(for: "2026-03-02"),
                notes: "Boundary stay"
            )
        )
        try context.save()

        let service = CalendarTabDataService(modelContainer: container)
        let snapshot = try await service.snapshot(
            visibleMonthStart: makeDate(2026, 3, 1),
            summaryRange: .visibleMonth,
            now: makeDate(2026, 3, 10)
        )

        let march1 = try XCTUnwrap(snapshot.daySummaries.first { $0.dayKey == "2026-03-01" })
        let march2 = try XCTUnwrap(snapshot.daySummaries.first { $0.dayKey == "2026-03-02" })

        XCTAssertEqual(march1.countries.map(\.id), ["FR"])
        XCTAssertEqual(march2.countries.map(\.id), ["FR"])
        XCTAssertEqual(snapshot.countrySummaries.first?.id, "FR")
        XCTAssertEqual(snapshot.countrySummaries.first?.totalDays, 2)
    }

    func testSnapshotAppliesRollingSummaryRangeToTableOnly() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let timeZoneID = TimeZone.current.identifier

        let records: [(String, String, String)] = [
            ("2026-03-15", "US", "United States"),
            ("2025-10-01", "CA", "Canada"),
            ("2024-12-31", "MX", "Mexico")
        ]

        for (index, record) in records.enumerated() {
            context.insert(
                LocationSample(
                    timestamp: makeDate(index == 0 ? 2026 : (index == 1 ? 2025 : 2024), index == 0 ? 3 : (index == 1 ? 10 : 12), index == 0 ? 15 : (index == 1 ? 1 : 31)),
                    latitude: Double(index),
                    longitude: Double(index),
                    accuracyMeters: 15,
                    source: .app,
                    timeZoneId: timeZoneID,
                    dayKey: record.0,
                    countryCode: record.1,
                    countryName: record.2
                )
            )
        }
        try context.save()

        let service = CalendarTabDataService(modelContainer: container)
        let snapshot = try await service.snapshot(
            visibleMonthStart: makeDate(2026, 3, 1),
            summaryRange: .last12Months,
            now: makeDate(2026, 3, 19)
        )

        XCTAssertEqual(Set(snapshot.countrySummaries.map(\.id)), Set(["US", "CA"]))
        XCTAssertFalse(snapshot.countrySummaries.map(\.id).contains("MX"))

        let visibleMonthCountryIDs = Set(snapshot.daySummaries.flatMap(\.countries).map(\.id))
        XCTAssertEqual(visibleMonthCountryIDs, Set(["US"]))
    }

    func testSnapshotFallsBackToCountryNameAndTracksMonthBounds() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(
            PhotoSignal(
                timestamp: makeDate(2025, 1, 5),
                latitude: 0,
                longitude: 0,
                assetIdHash: "asset-atlantis",
                timeZoneId: TimeZone.current.identifier,
                dayKey: "2025-01-05",
                countryCode: nil,
                countryName: "Atlantis"
            )
        )
        try context.save()

        let now = makeDate(2026, 3, 19)
        let service = CalendarTabDataService(modelContainer: container)
        let snapshot = try await service.snapshot(
            visibleMonthStart: makeDate(2025, 1, 1),
            summaryRange: .visibleMonth,
            now: now
        )

        let atlantis = try XCTUnwrap(snapshot.countrySummaries.first)
        XCTAssertEqual(atlantis.id, "Atlantis")
        XCTAssertEqual(atlantis.countryCode, nil)
        XCTAssertEqual(atlantis.countryName, "Atlantis")
        XCTAssertEqual(atlantis.totalDays, 1)

        let earliestComponents = Calendar.current.dateComponents([.year, .month], from: snapshot.earliestAvailableMonth)
        XCTAssertEqual(earliestComponents.year, 2025)
        XCTAssertEqual(earliestComponents.month, 1)

        let latestComponents = Calendar.current.dateComponents([.year, .month], from: snapshot.latestAvailableMonth)
        let expectedLatestComponents = Calendar.current.dateComponents([.year, .month], from: now)
        XCTAssertEqual(latestComponents.year, expectedLatestComponents.year)
        XCTAssertEqual(latestComponents.month, expectedLatestComponents.month)

        let fallbackInfo = CountryDaysInfo(
            countryName: atlantis.countryName,
            countryCode: atlantis.countryCode,
            totalDays: atlantis.totalDays,
            region: Region(rawValue: atlantis.regionRaw) ?? .other,
            maxAllowedDays: atlantis.maxAllowedDays
        )
        XCTAssertEqual(fallbackInfo.flagEmoji, "🌍")
    }
}
