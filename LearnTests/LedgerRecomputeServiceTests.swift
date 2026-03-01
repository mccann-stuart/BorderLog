#if canImport(XCTest)
import XCTest
import SwiftData
@testable import Learn

@MainActor
final class LedgerRecomputeServiceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var service: LedgerRecomputeService!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: PresenceDay.self, Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, CalendarSignal.self, configurations: config)
        context = container.mainContext
        service = LedgerRecomputeService(modelContainer: container)
    }

    func testRecomputeUpdatesPresenceDays() async throws {
        // Setup initial data
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let dayKey = DayKey.make(from: today, timeZone: calendar.timeZone)

        // 1. Initial Insert: Create a stay for today in Spain
        let stay = Stay(
            countryName: "Spain",
            region: .schengen,
            enteredOn: today,
            exitedOn: tomorrow
        )
        context.insert(stay)
        try context.save()

        // Run recompute for the specific dayKey
        await service.recompute(dayKeys: [dayKey])

        // Verify PresenceDay created with correct country
        var descriptor = FetchDescriptor<PresenceDay>(predicate: #Predicate { $0.dayKey == dayKey })
        var fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.countryName, "Spain")
        XCTAssertEqual(fetched.first?.stayCount, 1)

        // 2. Update: Change stay to France
        stay.countryName = "France"
        try context.save()

        // Run recompute again
        await service.recompute(dayKeys: [dayKey])

        // Verify PresenceDay updated
        fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.countryName, "France")
        XCTAssertEqual(fetched.first?.stayCount, 1)

        // 3. Delete: Remove the stay
        context.delete(stay)
        try context.save()

        // Run recompute again
        await service.recompute(dayKeys: [dayKey])

        // Verify PresenceDay updated to reflect no stay (or deleted depending on logic, but likely just updated to empty/unknown)
        fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        // Without stay, country should be nil or based on other signals. Here nil.
        XCTAssertNil(fetched.first?.countryName)
        XCTAssertEqual(fetched.first?.stayCount, 0)
    }

    func testFillMissingDaysCreatesContinuousRange() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let asOf = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 2,
            day: 23
        ).date!

        await service.fillMissingDays(asOf: asOf, calendar: calendar)

        let days = try context.fetch(FetchDescriptor<PresenceDay>())
        let today = calendar.startOfDay(for: asOf)
        let start = calendar.date(byAdding: .year, value: -2, to: today)!
        let expectedKeys = makeDayKeys(from: start, to: today, calendar: calendar)

        XCTAssertEqual(days.count, expectedKeys.count)

        let actualKeys = Set(days.map { $0.dayKey })
        XCTAssertEqual(actualKeys, Set(expectedKeys))

        let sortedActual = actualKeys.sorted()
        XCTAssertEqual(sortedActual.first, expectedKeys.first)
        XCTAssertEqual(sortedActual.last, expectedKeys.last)
    }

    func testFillMissingDaysIsIdempotent() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let asOf = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 2,
            day: 23
        ).date!

        await service.fillMissingDays(asOf: asOf, calendar: calendar)
        let count1 = try context.fetchCount(FetchDescriptor<PresenceDay>())

        await service.fillMissingDays(asOf: asOf, calendar: calendar)
        let count2 = try context.fetchCount(FetchDescriptor<PresenceDay>())

        XCTAssertEqual(count1, count2)
    }

    func testRecomputeExpandsSeedByDependencyPadding() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let mock = MockLedgerDataFetcher()
        await service.setMock(mock)

        let seedDate = date(2026, 1, 10, calendar: calendar)
        let seedKey = DayKey.make(from: seedDate, timeZone: calendar.timeZone)
        await service.recompute(dayKeys: [seedKey])

        let expectedStart = calendar.date(byAdding: .day, value: -8, to: seedDate)!
        let expectedEnd = calendar.date(byAdding: .day, value: 8, to: seedDate)!
        let expectedKeys = Set(makeDayKeys(from: expectedStart, to: expectedEnd, calendar: calendar))

        XCTAssertEqual(Set(mock.insertedPresenceDayKeys), expectedKeys)
    }

    func testRecomputeExpandsToNearestKnownAnchors() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let mock = MockLedgerDataFetcher()
        await service.setMock(mock)

        let seedDate = date(2026, 1, 10, calendar: calendar)
        let seedKey = DayKey.make(from: seedDate, timeZone: calendar.timeZone)

        let leftAnchorDate = date(2025, 12, 28, calendar: calendar)
        let rightAnchorDate = date(2026, 1, 24, calendar: calendar)
        let leftAnchorKey = DayKey.make(from: leftAnchorDate, timeZone: calendar.timeZone)
        let rightAnchorKey = DayKey.make(from: rightAnchorDate, timeZone: calendar.timeZone)

        mock.presenceDays[leftAnchorKey] = knownPresenceDay(dayKey: leftAnchorKey, date: leftAnchorDate, timeZoneId: calendar.timeZone.identifier)
        mock.presenceDays[rightAnchorKey] = knownPresenceDay(dayKey: rightAnchorKey, date: rightAnchorDate, timeZoneId: calendar.timeZone.identifier)

        await service.recompute(dayKeys: [seedKey])

        let expectedKeys = Set(makeDayKeys(from: leftAnchorDate, to: rightAnchorDate, calendar: calendar))
        XCTAssertEqual(Set(mock.presenceDays.keys), expectedKeys)
    }

    func testRecomputeClampsExpandedScopeToToday() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let mock = MockLedgerDataFetcher()
        await service.setMock(mock)

        let today = calendar.startOfDay(for: Date())
        let seedKey = DayKey.make(from: today, timeZone: calendar.timeZone)
        let futureAnchorDate = calendar.date(byAdding: .day, value: 30, to: today)!
        let futureAnchorKey = DayKey.make(from: futureAnchorDate, timeZone: calendar.timeZone)
        mock.presenceDays[futureAnchorKey] = knownPresenceDay(dayKey: futureAnchorKey, date: futureAnchorDate, timeZoneId: calendar.timeZone.identifier)

        await service.recompute(dayKeys: [seedKey])

        let insertedDates = mock.insertedPresenceDayKeys.compactMap {
            DayKey.date(for: $0, timeZone: calendar.timeZone).map { calendar.startOfDay(for: $0) }
        }
        XCTAssertFalse(insertedDates.isEmpty)
        XCTAssertEqual(insertedDates.max(), today)
    }

    func testRecomputePersistsDisputedFlagWhenUpdatingExistingPresenceDay() async throws {
        let calendar = Calendar.current
        let seedDate = calendar.startOfDay(for: Date())
        let seedKey = DayKey.make(from: seedDate, timeZone: calendar.timeZone)

        let mock = MockLedgerDataFetcher()
        await service.setMock(mock)

        mock.presenceDays[seedKey] = PresenceDay(
            dayKey: seedKey,
            date: seedDate,
            timeZoneId: calendar.timeZone.identifier,
            countryCode: "FR",
            countryName: "France",
            confidence: 0.5,
            confidenceLabel: .medium,
            sources: [.photo],
            isOverride: false,
            stayCount: 0,
            photoCount: 1,
            locationCount: 0,
            calendarCount: 0,
            isDisputed: false
        )

        mock.photos = [
            makePhotoSignal(day: seedDate, dayKey: seedKey, countryCode: "FR", countryName: "France", assetIdHash: "asset-1"),
            makePhotoSignal(day: seedDate, dayKey: seedKey, countryCode: "FR", countryName: "France", assetIdHash: "asset-2"),
            makePhotoSignal(day: seedDate, dayKey: seedKey, countryCode: "ES", countryName: "Spain", assetIdHash: "asset-3")
        ]

        await service.recompute(dayKeys: [seedKey])

        let updated = mock.presenceDays[seedKey]
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.countryCode, "FR")
        XCTAssertEqual(updated?.isDisputed, true)
    }

    func testRecomputePersistsDisputedFlagWhenInsertingPresenceDay() async throws {
        let calendar = Calendar.current
        let seedDate = calendar.startOfDay(for: Date())
        let seedKey = DayKey.make(from: seedDate, timeZone: calendar.timeZone)

        let mock = MockLedgerDataFetcher()
        await service.setMock(mock)

        mock.photos = [
            makePhotoSignal(day: seedDate, dayKey: seedKey, countryCode: "FR", countryName: "France", assetIdHash: "asset-11"),
            makePhotoSignal(day: seedDate, dayKey: seedKey, countryCode: "FR", countryName: "France", assetIdHash: "asset-12"),
            makePhotoSignal(day: seedDate, dayKey: seedKey, countryCode: "ES", countryName: "Spain", assetIdHash: "asset-13")
        ]

        await service.recompute(dayKeys: [seedKey])

        let inserted = mock.presenceDays[seedKey]
        XCTAssertNotNil(inserted)
        XCTAssertEqual(inserted?.countryCode, "FR")
        XCTAssertEqual(inserted?.isDisputed, true)
    }

    private func makeDayKeys(from start: Date, to end: Date, calendar: Calendar) -> [String] {
        let timeZone = calendar.timeZone
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else { return [] }

        var day = startDay
        var keys: [String] = []
        while day <= endDay {
            keys.append(DayKey.make(from: day, timeZone: timeZone))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return keys
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: year, month: month, day: day).date!
    }

    private func knownPresenceDay(dayKey: String, date: Date, timeZoneId: String) -> PresenceDay {
        PresenceDay(
            dayKey: dayKey,
            date: date,
            timeZoneId: timeZoneId,
            countryCode: "FR",
            countryName: "France",
            confidence: 1.0,
            confidenceLabel: .high,
            sources: .stay,
            isOverride: false,
            stayCount: 1,
            photoCount: 0,
            locationCount: 0,
            calendarCount: 0
        )
    }

    private func makePhotoSignal(day: Date, dayKey: String, countryCode: String, countryName: String, assetIdHash: String) -> PhotoSignal {
        let timestamp = Calendar.current.date(byAdding: .hour, value: 12, to: day) ?? day
        return PhotoSignal(
            timestamp: timestamp,
            latitude: 0,
            longitude: 0,
            assetIdHash: assetIdHash,
            timeZoneId: Calendar.current.timeZone.identifier,
            dayKey: dayKey,
            countryCode: countryCode,
            countryName: countryName
        )
    }
}
#endif
