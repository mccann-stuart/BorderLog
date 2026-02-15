
import XCTest
import Foundation
import SwiftData
@testable import Learn
final class PerformanceTests: XCTestCase {

    @MainActor
    func testBenchmarkFetchPerformance() async throws {
        let schema = Schema([Stay.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        // Populate with 10,000 stays
        print("Populating 10,000 stays...")
        let calendar = Calendar.current
        let baseDate = Date()

        for i in 0..<10_000 {
            // Distribute stays over ~10 years
            let start = calendar.date(byAdding: .day, value: i - 5000, to: baseDate)!
            let end = calendar.date(byAdding: .day, value: 5, to: start)
            let stay = Stay(countryName: "Country \(i)", region: .schengen, enteredOn: start, exitedOn: end)
            context.insert(stay)
        }
        try context.save()
        print("Population complete.")

        // Benchmark 1: Fetch All (simulating @Query)
        let startTimeAll = Date()
        let descriptorAll = FetchDescriptor<Stay>(sortBy: [SortDescriptor(\.enteredOn, order: .reverse)])
        let allStays = try context.fetch(descriptorAll)
        let durationAll = Date().timeIntervalSince(startTimeAll)
        print("Fetch All (10,000 items) took: \(durationAll) seconds. Count: \(allStays.count)")

        // Benchmark 2: Fetch Overlapping (Predicate)
        // Simulate checking overlap for a new stay in the middle
        let checkStart = baseDate
        let checkEnd = calendar.date(byAdding: .day, value: 7, to: baseDate)!

        let startTimePredicate = Date()

        // Predicate: stay.enteredOn <= checkEnd AND (stay.exitedOn ?? distantFuture) >= checkStart
        // Note: Using a predicate that works with SwiftData
        let distantFuture = Date.distantFuture
        let predicate = #Predicate<Stay> { stay in
            stay.enteredOn <= checkEnd && (stay.exitedOn ?? distantFuture) >= checkStart
        }

        var descriptorPredicate = FetchDescriptor<Stay>(predicate: predicate)
        descriptorPredicate.sortBy = [SortDescriptor(\.enteredOn, order: .reverse)]

        let overlappingStays = try context.fetch(descriptorPredicate)
        let durationPredicate = Date().timeIntervalSince(startTimePredicate)

        print("Fetch Overlapping (Predicate) took: \(durationPredicate) seconds. Count: \(overlappingStays.count)")

        // Assertion to ensure we are actually testing what we think
        XCTAssertTrue(durationPredicate < durationAll, "Predicate fetch should be faster than fetching all")
    }
}
