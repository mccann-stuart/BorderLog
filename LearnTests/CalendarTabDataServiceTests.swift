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

    private func localizedCountryName(_ code: String) -> String {
        Locale.autoupdatingCurrent.localizedString(forRegionCode: code) ?? code
    }

    private func makePresenceDay(
        dayKey: String,
        date: Date,
        timeZoneId: String,
        countryCode: String?,
        countryName: String?,
        confidence: Double,
        confidenceLabel: ConfidenceLabel,
        sources: SignalSourceMask,
        isOverride: Bool = false,
        stayCount: Int,
        photoCount: Int,
        locationCount: Int,
        calendarCount: Int,
        suggestedCountryCode1: String? = nil,
        suggestedCountryName1: String? = nil,
        suggestedCountryCode2: String? = nil,
        suggestedCountryName2: String? = nil
    ) -> PresenceDay {
        let contributedCountries: [ContributedCountry]
        if let countryName {
            contributedCountries = [
                ContributedCountry(countryCode: countryCode, countryName: countryName, probability: 1.0)
            ]
        } else {
            contributedCountries = []
        }

        return PresenceDay(
            dayKey: dayKey,
            date: date,
            timeZoneId: timeZoneId,
            contributedCountries: contributedCountries,
            zoneOverlays: [],
            evidence: [],
            confidence: confidence,
            confidenceLabel: confidenceLabel,
            sources: sources,
            isOverride: isOverride,
            stayCount: stayCount,
            photoCount: photoCount,
            locationCount: locationCount,
            calendarCount: calendarCount,
            suggestedCountryCode1: suggestedCountryCode1,
            suggestedCountryName1: suggestedCountryName1,
            suggestedCountryCode2: suggestedCountryCode2,
            suggestedCountryName2: suggestedCountryName2
        )
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
                source: "CalendarFlight"
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
        XCTAssertNil(march19.flightOriginCountry)
        XCTAssertEqual(march19.flightDestinationCountry?.id, "GB")
        XCTAssertEqual(march19.countries.map(\.id), ["GB", "US"])

        let totals = snapshot.countrySummaries.reduce(into: [String: CalendarCountryDaysSummary](minimumCapacity: snapshot.countrySummaries.count)) { dict, summary in
            if dict[summary.id] == nil {
                dict[summary.id] = summary
            }
        }
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

    func testSnapshotCountsResolvedBridgeDaysWithoutRawEvidence() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let bridgeDayKey = "2026-03-16"
        let bridgeDate = normalizedDate(for: bridgeDayKey)
        let spainName = localizedCountryName("ES")

        context.insert(
            makePresenceDay(
                dayKey: bridgeDayKey,
                date: bridgeDate,
                timeZoneId: TimeZone.current.identifier,
                countryCode: nil,
                countryName: spainName,
                confidence: 0.5,
                confidenceLabel: .medium,
                sources: .none,
                isOverride: false,
                stayCount: 0,
                photoCount: 0,
                locationCount: 0,
                calendarCount: 0
            )
        )
        try context.save()

        let service = CalendarTabDataService(modelContainer: container)
        let snapshot = try await service.snapshot(
            visibleMonthStart: makeDate(2026, 3, 1),
            summaryRange: .visibleMonth,
            now: makeDate(2026, 3, 19)
        )

        let bridgeDay = try XCTUnwrap(snapshot.daySummaries.first { $0.dayKey == bridgeDayKey })
        XCTAssertEqual(bridgeDay.countries.map(\.id), ["ES"])
        XCTAssertEqual(bridgeDay.countries.first?.countryCode, "ES")

        let totals = snapshot.countrySummaries.reduce(into: [String: CalendarCountryDaysSummary](minimumCapacity: snapshot.countrySummaries.count)) { dict, summary in
            if dict[summary.id] == nil {
                dict[summary.id] = summary
            }
        }
        XCTAssertEqual(totals["ES"]?.countryName, spainName)
        XCTAssertEqual(totals["ES"]?.totalDays, 1)
        XCTAssertEqual(snapshot.countrySummaries.count, 1)
    }

    func testSnapshotMergesNameOnlyResolvedDaysIntoCodedCountrySummary() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let spainName = localizedCountryName("ES")

        context.insert(
            makePresenceDay(
                dayKey: "2026-03-15",
                date: normalizedDate(for: "2026-03-15"),
                timeZoneId: TimeZone.current.identifier,
                countryCode: "ES",
                countryName: spainName,
                confidence: 1,
                confidenceLabel: .high,
                sources: .location,
                isOverride: false,
                stayCount: 0,
                photoCount: 0,
                locationCount: 1,
                calendarCount: 0
            )
        )
        context.insert(
            makePresenceDay(
                dayKey: "2026-03-16",
                date: normalizedDate(for: "2026-03-16"),
                timeZoneId: TimeZone.current.identifier,
                countryCode: nil,
                countryName: spainName,
                confidence: 0.5,
                confidenceLabel: .medium,
                sources: .none,
                isOverride: false,
                stayCount: 0,
                photoCount: 0,
                locationCount: 0,
                calendarCount: 0
            )
        )
        try context.save()

        let service = CalendarTabDataService(modelContainer: container)
        let snapshot = try await service.snapshot(
            visibleMonthStart: makeDate(2026, 3, 1),
            summaryRange: .visibleMonth,
            now: makeDate(2026, 3, 19)
        )

        XCTAssertEqual(snapshot.countrySummaries.count, 1)
        XCTAssertEqual(snapshot.countrySummaries.first?.id, "ES")
        XCTAssertEqual(snapshot.countrySummaries.first?.countryName, spainName)
        XCTAssertEqual(snapshot.countrySummaries.first?.totalDays, 2)

        let march16 = try XCTUnwrap(snapshot.daySummaries.first { $0.dayKey == "2026-03-16" })
        XCTAssertEqual(march16.countries.map(\.id), ["ES"])
    }

    func testSnapshotTracksUnknownSummaryDaysForSelectedRange() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(
            makePresenceDay(
                dayKey: "2025-10-01",
                date: normalizedDate(for: "2025-10-01"),
                timeZoneId: TimeZone.current.identifier,
                countryCode: nil,
                countryName: nil,
                confidence: 0,
                confidenceLabel: .low,
                sources: .none,
                isOverride: false,
                stayCount: 0,
                photoCount: 0,
                locationCount: 0,
                calendarCount: 0
            )
        )
        context.insert(
            makePresenceDay(
                dayKey: "2026-03-15",
                date: normalizedDate(for: "2026-03-15"),
                timeZoneId: TimeZone.current.identifier,
                countryCode: "US",
                countryName: localizedCountryName("US"),
                confidence: 1,
                confidenceLabel: .high,
                sources: .location,
                isOverride: false,
                stayCount: 0,
                photoCount: 0,
                locationCount: 1,
                calendarCount: 0
            )
        )
        try context.save()

        let service = CalendarTabDataService(modelContainer: container)
        let snapshot = try await service.snapshot(
            visibleMonthStart: makeDate(2026, 3, 1),
            summaryRange: .last12Months,
            now: makeDate(2026, 3, 19)
        )

        XCTAssertEqual(snapshot.summaryUnknownDayKeys, ["2025-10-01"])
        XCTAssertEqual(snapshot.countrySummaries.map(\.id), ["US"])
        XCTAssertNil(snapshot.daySummaries.first { $0.dayKey == "2025-10-01" })
    }

    func testSnapshotKeepsFlightOriginAndDestinationWhenResolvedDayMatchesDestination() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dayKey = "2026-03-15"
        let timeZoneID = TimeZone.current.identifier

        context.insert(
            makePresenceDay(
                dayKey: dayKey,
                date: normalizedDate(for: dayKey),
                timeZoneId: timeZoneID,
                countryCode: "US",
                countryName: localizedCountryName("US"),
                confidence: 0.5,
                confidenceLabel: .medium,
                sources: .calendar,
                isOverride: false,
                stayCount: 0,
                photoCount: 0,
                locationCount: 0,
                calendarCount: 1
            )
        )
        context.insert(
            CalendarSignal(
                timestamp: makeDate(2026, 3, 15, hour: 8),
                dayKey: dayKey,
                latitude: 51.4700,
                longitude: -0.4543,
                countryCode: "GB",
                countryName: localizedCountryName("GB"),
                timeZoneId: "Europe/London",
                bucketingTimeZoneId: "Europe/London",
                eventIdentifier: "flight-1#origin",
                title: "LHR to JFK",
                source: "CalendarFlightOrigin"
            )
        )
        context.insert(
            CalendarSignal(
                timestamp: makeDate(2026, 3, 15, hour: 16),
                dayKey: dayKey,
                latitude: 40.6413,
                longitude: -73.7781,
                countryCode: "US",
                countryName: localizedCountryName("US"),
                timeZoneId: "America/New_York",
                bucketingTimeZoneId: "America/New_York",
                eventIdentifier: "flight-1",
                title: "LHR to JFK",
                source: "CalendarFlight"
            )
        )
        try context.save()

        let service = CalendarTabDataService(modelContainer: container)
        let snapshot = try await service.snapshot(
            visibleMonthStart: makeDate(2026, 3, 1),
            summaryRange: .visibleMonth,
            now: makeDate(2026, 3, 19)
        )

        let march15 = try XCTUnwrap(snapshot.daySummaries.first { $0.dayKey == dayKey })
        XCTAssertTrue(march15.hasFlight)
        XCTAssertEqual(march15.flightOriginCountry?.id, "GB")
        XCTAssertEqual(march15.flightDestinationCountry?.id, "US")
        XCTAssertEqual(march15.countries.map(\.id), ["GB", "US"])
    }

    func testSnapshotDedupesResolvedCountryWhenItMatchesFlightOrigin() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dayKey = "2026-03-16"
        let timeZoneID = TimeZone.current.identifier

        context.insert(
            makePresenceDay(
                dayKey: dayKey,
                date: normalizedDate(for: dayKey),
                timeZoneId: timeZoneID,
                countryCode: "GB",
                countryName: localizedCountryName("GB"),
                confidence: 0.5,
                confidenceLabel: .medium,
                sources: .calendar,
                isOverride: false,
                stayCount: 0,
                photoCount: 0,
                locationCount: 0,
                calendarCount: 1
            )
        )
        context.insert(
            CalendarSignal(
                timestamp: makeDate(2026, 3, 16, hour: 7),
                dayKey: dayKey,
                latitude: 51.4700,
                longitude: -0.4543,
                countryCode: "GB",
                countryName: localizedCountryName("GB"),
                timeZoneId: "Europe/London",
                bucketingTimeZoneId: "Europe/London",
                eventIdentifier: "flight-2#origin",
                title: "LHR to CDG",
                source: "CalendarFlightOrigin"
            )
        )
        context.insert(
            CalendarSignal(
                timestamp: makeDate(2026, 3, 16, hour: 10),
                dayKey: dayKey,
                latitude: 49.0097,
                longitude: 2.5479,
                countryCode: "FR",
                countryName: localizedCountryName("FR"),
                timeZoneId: "Europe/Paris",
                bucketingTimeZoneId: "Europe/Paris",
                eventIdentifier: "flight-2",
                title: "LHR to CDG",
                source: "CalendarFlight"
            )
        )
        try context.save()

        let service = CalendarTabDataService(modelContainer: container)
        let snapshot = try await service.snapshot(
            visibleMonthStart: makeDate(2026, 3, 1),
            summaryRange: .visibleMonth,
            now: makeDate(2026, 3, 19)
        )

        let march16 = try XCTUnwrap(snapshot.daySummaries.first { $0.dayKey == dayKey })
        XCTAssertEqual(march16.flightOriginCountry?.id, "GB")
        XCTAssertEqual(march16.flightDestinationCountry?.id, "FR")
        XCTAssertEqual(march16.countries.map(\.id), ["GB", "FR"])
    }

    func testSnapshotUsesFirstOriginAndLastDestinationForMultiFlightDay() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dayKey = "2026-03-18"

        context.insert(
            CalendarSignal(
                timestamp: makeDate(2026, 3, 18, hour: 7),
                dayKey: dayKey,
                latitude: 51.4700,
                longitude: -0.4543,
                countryCode: "GB",
                countryName: localizedCountryName("GB"),
                timeZoneId: "Europe/London",
                bucketingTimeZoneId: "Europe/London",
                eventIdentifier: "flight-a#origin",
                title: "LHR to FRA",
                source: "CalendarFlightOrigin"
            )
        )
        context.insert(
            CalendarSignal(
                timestamp: makeDate(2026, 3, 18, hour: 10),
                dayKey: dayKey,
                latitude: 50.0379,
                longitude: 8.5622,
                countryCode: "DE",
                countryName: localizedCountryName("DE"),
                timeZoneId: "Europe/Berlin",
                bucketingTimeZoneId: "Europe/Berlin",
                eventIdentifier: "flight-a",
                title: "LHR to FRA",
                source: "CalendarFlight"
            )
        )
        context.insert(
            CalendarSignal(
                timestamp: makeDate(2026, 3, 18, hour: 12),
                dayKey: dayKey,
                latitude: 49.0097,
                longitude: 2.5479,
                countryCode: "FR",
                countryName: localizedCountryName("FR"),
                timeZoneId: "Europe/Paris",
                bucketingTimeZoneId: "Europe/Paris",
                eventIdentifier: "flight-b#origin",
                title: "CDG to JFK",
                source: "CalendarFlightOrigin"
            )
        )
        context.insert(
            CalendarSignal(
                timestamp: makeDate(2026, 3, 18, hour: 18),
                dayKey: dayKey,
                latitude: 40.6413,
                longitude: -73.7781,
                countryCode: "US",
                countryName: localizedCountryName("US"),
                timeZoneId: "America/New_York",
                bucketingTimeZoneId: "America/New_York",
                eventIdentifier: "flight-b",
                title: "CDG to JFK",
                source: "CalendarFlight"
            )
        )
        try context.save()

        let service = CalendarTabDataService(modelContainer: container)
        let snapshot = try await service.snapshot(
            visibleMonthStart: makeDate(2026, 3, 1),
            summaryRange: .visibleMonth,
            now: makeDate(2026, 3, 19)
        )

        let march18 = try XCTUnwrap(snapshot.daySummaries.first { $0.dayKey == dayKey })
        XCTAssertEqual(march18.flightOriginCountry?.id, "GB")
        XCTAssertEqual(march18.flightDestinationCountry?.id, "US")
        XCTAssertEqual(march18.countries.map(\.id), ["GB", "US", "DE", "FR"])
    }

    func testSnapshotKeepsNonFlightCalendarEvidenceWithoutPlaneDecoration() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dayKey = "2026-03-12"

        context.insert(
            CalendarSignal(
                timestamp: makeDate(2026, 3, 12, hour: 9),
                dayKey: dayKey,
                latitude: 48.8566,
                longitude: 2.3522,
                countryCode: "FR",
                countryName: localizedCountryName("FR"),
                timeZoneId: "Europe/Paris",
                bucketingTimeZoneId: "Europe/Paris",
                eventIdentifier: "train-1",
                title: "Train to Paris",
                source: "Calendar"
            )
        )
        try context.save()

        let service = CalendarTabDataService(modelContainer: container)
        let snapshot = try await service.snapshot(
            visibleMonthStart: makeDate(2026, 3, 1),
            summaryRange: .visibleMonth,
            now: makeDate(2026, 3, 19)
        )

        let march12 = try XCTUnwrap(snapshot.daySummaries.first { $0.dayKey == dayKey })
        XCTAssertFalse(march12.hasFlight)
        XCTAssertNil(march12.flightOriginCountry)
        XCTAssertNil(march12.flightDestinationCountry)
        XCTAssertEqual(march12.countries.map(\.id), ["FR"])
    }

    func testSnapshotPrefersResolvedCountryWhenFlightOriginsShareTimestamp() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dayKey = "2026-03-10"
        let timeZoneID = TimeZone.current.identifier

        context.insert(
            makePresenceDay(
                dayKey: dayKey,
                date: normalizedDate(for: dayKey),
                timeZoneId: timeZoneID,
                countryCode: "GB",
                countryName: localizedCountryName("GB"),
                confidence: 0.6,
                confidenceLabel: .medium,
                sources: .calendar,
                isOverride: false,
                stayCount: 0,
                photoCount: 0,
                locationCount: 0,
                calendarCount: 3
            )
        )
        context.insert(
            CalendarSignal(
                timestamp: makeDate(2026, 3, 10, hour: 8),
                dayKey: dayKey,
                latitude: 40.6413,
                longitude: -73.7781,
                countryCode: "US",
                countryName: localizedCountryName("US"),
                timeZoneId: "America/New_York",
                bucketingTimeZoneId: "America/New_York",
                eventIdentifier: "flight-a#origin",
                title: "JFK to LHR",
                source: "CalendarFlightOrigin"
            )
        )
        context.insert(
            CalendarSignal(
                timestamp: makeDate(2026, 3, 10, hour: 8),
                dayKey: dayKey,
                latitude: 51.4700,
                longitude: -0.4543,
                countryCode: "GB",
                countryName: localizedCountryName("GB"),
                timeZoneId: "Europe/London",
                bucketingTimeZoneId: "Europe/London",
                eventIdentifier: "flight-b#origin",
                title: "LHR to FRA",
                source: "CalendarFlightOrigin"
            )
        )
        context.insert(
            CalendarSignal(
                timestamp: makeDate(2026, 3, 10, hour: 14),
                dayKey: dayKey,
                latitude: 50.0379,
                longitude: 8.5622,
                countryCode: "DE",
                countryName: localizedCountryName("DE"),
                timeZoneId: "Europe/Berlin",
                bucketingTimeZoneId: "Europe/Berlin",
                eventIdentifier: "flight-b",
                title: "LHR to FRA",
                source: "CalendarFlight"
            )
        )
        try context.save()

        let service = CalendarTabDataService(modelContainer: container)
        let snapshot = try await service.snapshot(
            visibleMonthStart: makeDate(2026, 3, 1),
            summaryRange: .visibleMonth,
            now: makeDate(2026, 3, 19)
        )

        let march10 = try XCTUnwrap(snapshot.daySummaries.first { $0.dayKey == dayKey })
        XCTAssertTrue(march10.hasFlight)
        XCTAssertEqual(march10.flightOriginCountry?.id, "GB")
        XCTAssertEqual(march10.flightDestinationCountry?.id, "DE")
        XCTAssertEqual(march10.countries.map(\.id), ["GB", "DE", "US"])
    }

    func testSnapshotFallsBackToSuggestionsWhenResolvedAndRawCountriesAreMissing() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dayKey = "2026-03-07"

        context.insert(
            makePresenceDay(
                dayKey: dayKey,
                date: normalizedDate(for: dayKey),
                timeZoneId: TimeZone.current.identifier,
                countryCode: nil,
                countryName: nil,
                confidence: 0.0,
                confidenceLabel: .low,
                sources: .none,
                isOverride: false,
                stayCount: 0,
                photoCount: 0,
                locationCount: 0,
                calendarCount: 0,
                suggestedCountryCode1: "GB",
                suggestedCountryName1: localizedCountryName("GB"),
                suggestedCountryCode2: "DE",
                suggestedCountryName2: localizedCountryName("DE")
            )
        )
        try context.save()

        let service = CalendarTabDataService(modelContainer: container)
        let snapshot = try await service.snapshot(
            visibleMonthStart: makeDate(2026, 3, 1),
            summaryRange: .visibleMonth,
            now: makeDate(2026, 3, 19)
        )

        let march7 = try XCTUnwrap(snapshot.daySummaries.first { $0.dayKey == dayKey })
        XCTAssertFalse(march7.hasFlight)
        XCTAssertEqual(march7.countries.map(\.id), ["GB", "DE"])
        XCTAssertTrue(snapshot.countrySummaries.isEmpty)
    }
}
