
import XCTest
import Foundation
import SwiftData
@testable import Learn

final class DayOverridePerformanceTests: XCTestCase {

    @MainActor
    func testBenchmarkFetchOverridesPerformance() async throws {
        let schema = Schema([DayOverride.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        // Populate with 10,000 overrides
        print("Populating 10,000 overrides...")
        let calendar = Calendar.current
        let baseDate = Date()

        for i in 0..<10_000 {
            // Distribute overrides over ~10 years
            let date = calendar.date(byAdding: .day, value: i - 5000, to: baseDate)!
            let override = DayOverride(date: date, countryName: "Country \(i)", countryCode: "C\(i)", region: .schengen, notes: "Note \(i)")
            context.insert(override)
        }
        try context.save()
        print("Population complete.")

        // Test parameters
        let checkStart = baseDate
        let checkEnd = calendar.date(byAdding: .day, value: 30, to: baseDate)!

        // Benchmark 1: Fetch All + Filter (Baseline)
        let startTimeAll = Date()
        let descriptorAll = FetchDescriptor<DayOverride>()
        let allOverrides = try context.fetch(descriptorAll)
        let filteredOverrides = allOverrides.filter { $0.date >= checkStart && $0.date <= checkEnd }
        let durationAll = Date().timeIntervalSince(startTimeAll)
        print("Fetch All + Filter (10,000 items) took: \(durationAll) seconds. Count: \(filteredOverrides.count)")

        // Benchmark 2: Fetch with Predicate (Optimization)
        let startTimePredicate = Date()
        let predicate = #Predicate<DayOverride> { override in
            override.date >= checkStart && override.date <= checkEnd
        }
        let descriptorPredicate = FetchDescriptor<DayOverride>(predicate: predicate)
        let predicateOverrides = try context.fetch(descriptorPredicate)
        let durationPredicate = Date().timeIntervalSince(startTimePredicate)
        print("Fetch with Predicate took: \(durationPredicate) seconds. Count: \(predicateOverrides.count)")

        // Verification
        XCTAssertEqual(filteredOverrides.count, predicateOverrides.count, "Both methods should return the same number of overrides")
        XCTAssertTrue(durationPredicate < durationAll, "Predicate fetch should be faster than fetching all")

        // Print improvement factor
        let factor = durationAll / durationPredicate
        print("Improvement factor: \(String(format: "%.2f", factor))x")
    }
}
