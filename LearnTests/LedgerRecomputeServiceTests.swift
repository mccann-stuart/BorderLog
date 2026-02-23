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
}
#endif
