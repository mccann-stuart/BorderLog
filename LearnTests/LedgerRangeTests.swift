#if canImport(XCTest)
import XCTest
import SwiftData
@testable import Learn

@MainActor
final class LedgerRangeTests: XCTestCase {

    func testRecomputeAllGeneratesTwoYearsOfHistoryEvenWithoutData() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, configurations: config)
        let service = LedgerRecomputeService(modelContainer: container)

        // Ensure database is empty
        let context = container.mainContext
        let count = try context.fetchCount(FetchDescriptor<PresenceDay>())
        XCTAssertEqual(count, 0)

        // Run recomputeAll
        await service.recomputeAll()

        // Check that we have ~730 days (2 years)
        let fetchedDays = try context.fetch(FetchDescriptor<PresenceDay>())
        let dayCount = fetchedDays.count

        // 2 years is roughly 730 days. Allow some margin for leap years and "today" boundary.
        // It should be at least 730 (2 * 365).
        XCTAssertGreaterThanOrEqual(dayCount, 730, "Should generate at least 2 years of history")

        // Specifically check for Sep 12, 2025 if we are simulating a date after that.
        // Since we use real Date(), we can't easily check specific past dates unless we know current date.
        // But we can check if the range covers the last 2 years.

        let sortedDays = fetchedDays.sorted { $0.date < $1.date }
        if let firstDay = sortedDays.first, let lastDay = sortedDays.last {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year], from: firstDay.date, to: lastDay.date)
            XCTAssertGreaterThanOrEqual(components.year ?? 0, 1, "Range should span at least one full year (actually ~2)")
        } else {
            XCTFail("No days generated")
        }
    }
}
#endif
