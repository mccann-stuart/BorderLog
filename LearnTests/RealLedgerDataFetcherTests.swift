import XCTest
import SwiftData
@testable import Learn

@MainActor
final class RealLedgerDataFetcherTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Stay.self,
            DayOverride.self,
            LocationSample.self,
            PhotoSignal.self,
            CalendarSignal.self,
            PresenceDay.self,
            configurations: config
        )
    }

    func testFetchRangeBoundariesAreInclusive() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fetcher = RealLedgerDataFetcher(modelContext: context)

        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 1, day: 20))!
        let beforeStart = calendar.date(byAdding: .day, value: -1, to: start)!
        let afterEnd = calendar.date(byAdding: .day, value: 1, to: end)!

        context.insert(Stay(countryName: "InRangeStart", enteredOn: beforeStart, exitedOn: start))
        context.insert(Stay(countryName: "InRangeEnd", enteredOn: end, exitedOn: nil))
        context.insert(Stay(countryName: "OutOfRange", enteredOn: afterEnd, exitedOn: nil))

        context.insert(DayOverride(date: start, countryName: "Start", countryCode: "ES", region: .schengen))
        context.insert(DayOverride(date: end, countryName: "End", countryCode: "FR", region: .schengen))
        context.insert(DayOverride(date: afterEnd, countryName: "Outside", countryCode: "GB", region: .nonSchengen))

        context.insert(LocationSample(timestamp: start, latitude: 0, longitude: 0, accuracyMeters: 10, source: .app, timeZoneId: "UTC", dayKey: "2026-01-10", countryCode: "ES", countryName: "Spain"))
        context.insert(LocationSample(timestamp: end, latitude: 0, longitude: 0, accuracyMeters: 10, source: .app, timeZoneId: "UTC", dayKey: "2026-01-20", countryCode: "FR", countryName: "France"))
        context.insert(LocationSample(timestamp: afterEnd, latitude: 0, longitude: 0, accuracyMeters: 10, source: .app, timeZoneId: "UTC", dayKey: "2026-01-21", countryCode: "GB", countryName: "United Kingdom"))

        context.insert(PhotoSignal(timestamp: start, latitude: 0, longitude: 0, assetIdHash: "asset-start", timeZoneId: "UTC", dayKey: "2026-01-10", countryCode: "ES", countryName: "Spain"))
        context.insert(PhotoSignal(timestamp: end, latitude: 0, longitude: 0, assetIdHash: "asset-end", timeZoneId: "UTC", dayKey: "2026-01-20", countryCode: "FR", countryName: "France"))
        context.insert(PhotoSignal(timestamp: afterEnd, latitude: 0, longitude: 0, assetIdHash: "asset-out", timeZoneId: "UTC", dayKey: "2026-01-21", countryCode: "GB", countryName: "United Kingdom"))

        context.insert(CalendarSignal(timestamp: start, dayKey: "2026-01-10", latitude: 0, longitude: 0, countryCode: "ES", countryName: "Spain", timeZoneId: "UTC", eventIdentifier: "event-start", title: "Flight", source: "Calendar"))
        context.insert(CalendarSignal(timestamp: end, dayKey: "2026-01-20", latitude: 0, longitude: 0, countryCode: "FR", countryName: "France", timeZoneId: "UTC", eventIdentifier: "event-end", title: "Flight", source: "Calendar"))
        context.insert(CalendarSignal(timestamp: afterEnd, dayKey: "2026-01-21", latitude: 0, longitude: 0, countryCode: "GB", countryName: "United Kingdom", timeZoneId: "UTC", eventIdentifier: "event-out", title: "Flight", source: "Calendar"))

        try context.save()

        XCTAssertEqual(try fetcher.fetchStays(from: start, to: end).count, 2)
        XCTAssertEqual(try fetcher.fetchOverrides(from: start, to: end).count, 2)
        XCTAssertEqual(try fetcher.fetchLocations(from: start, to: end).count, 2)
        XCTAssertEqual(try fetcher.fetchPhotos(from: start, to: end).count, 2)
        XCTAssertEqual(try fetcher.fetchCalendarSignals(from: start, to: end).count, 2)
    }

    func testEarliestDateFetchesReturnMinimumDates() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fetcher = RealLedgerDataFetcher(modelContext: context)

        let calendar = Calendar(identifier: .gregorian)
        let oldest = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let newer = calendar.date(from: DateComponents(year: 2025, month: 6, day: 1))!

        context.insert(Stay(countryName: "Spain", enteredOn: newer, exitedOn: nil))
        context.insert(Stay(countryName: "France", enteredOn: oldest, exitedOn: nil))

        context.insert(DayOverride(date: newer, countryName: "Spain", countryCode: "ES"))
        context.insert(DayOverride(date: oldest, countryName: "France", countryCode: "FR"))

        context.insert(LocationSample(timestamp: newer, latitude: 0, longitude: 0, accuracyMeters: 10, source: .app, timeZoneId: "UTC", dayKey: "2025-06-01", countryCode: "ES", countryName: "Spain"))
        context.insert(LocationSample(timestamp: oldest, latitude: 0, longitude: 0, accuracyMeters: 10, source: .app, timeZoneId: "UTC", dayKey: "2024-01-01", countryCode: "FR", countryName: "France"))

        context.insert(PhotoSignal(timestamp: newer, latitude: 0, longitude: 0, assetIdHash: "new-photo", timeZoneId: "UTC", dayKey: "2025-06-01", countryCode: "ES", countryName: "Spain"))
        context.insert(PhotoSignal(timestamp: oldest, latitude: 0, longitude: 0, assetIdHash: "old-photo", timeZoneId: "UTC", dayKey: "2024-01-01", countryCode: "FR", countryName: "France"))

        context.insert(CalendarSignal(timestamp: newer, dayKey: "2025-06-01", latitude: 0, longitude: 0, countryCode: "ES", countryName: "Spain", timeZoneId: "UTC", eventIdentifier: "new-event", title: "Flight", source: "Calendar"))
        context.insert(CalendarSignal(timestamp: oldest, dayKey: "2024-01-01", latitude: 0, longitude: 0, countryCode: "FR", countryName: "France", timeZoneId: "UTC", eventIdentifier: "old-event", title: "Flight", source: "Calendar"))

        try context.save()

        XCTAssertEqual(try fetcher.fetchEarliestStayDate(), oldest)
        XCTAssertEqual(try fetcher.fetchEarliestOverrideDate(), oldest)
        XCTAssertEqual(try fetcher.fetchEarliestLocationDate(), oldest)
        XCTAssertEqual(try fetcher.fetchEarliestPhotoDate(), oldest)
        XCTAssertEqual(try fetcher.fetchEarliestCalendarSignalDate(), oldest)
    }

    func testPresenceDayRangeAndNearestKnownQueries() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fetcher = RealLedgerDataFetcher(modelContext: context)

        let calendar = Calendar(identifier: .gregorian)
        let d1 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let d2 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 2))!
        let d3 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 3))!
        let d4 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 4))!

        context.insert(PresenceDay(dayKey: "2026-02-01", date: d1, timeZoneId: "UTC", countryCode: "ES", countryName: "Spain", confidence: 1, confidenceLabel: .high, sources: .stay, isOverride: false, stayCount: 1, photoCount: 0, locationCount: 0, calendarCount: 0))
        context.insert(PresenceDay(dayKey: "2026-02-02", date: d2, timeZoneId: "UTC", countryCode: nil, countryName: nil, confidence: 0, confidenceLabel: .low, sources: .none, isOverride: false, stayCount: 0, photoCount: 0, locationCount: 0, calendarCount: 0))
        context.insert(PresenceDay(dayKey: "2026-02-03", date: d3, timeZoneId: "UTC", countryCode: "FR", countryName: "France", confidence: 1, confidenceLabel: .high, sources: .stay, isOverride: false, stayCount: 1, photoCount: 0, locationCount: 0, calendarCount: 0))
        try context.save()

        let keys = try fetcher.fetchPresenceDayKeys(from: d1, to: d3)
        XCTAssertEqual(keys, Set(["2026-02-01", "2026-02-02", "2026-02-03"]))

        let before = try fetcher.fetchNearestKnownPresenceDay(before: d3)
        XCTAssertEqual(before?.dayKey, "2026-02-01")

        let after = try fetcher.fetchNearestKnownPresenceDay(after: d2)
        XCTAssertEqual(after?.dayKey, "2026-02-03")

        XCTAssertNil(try fetcher.fetchNearestKnownPresenceDay(after: d4))
    }
}
