
import XCTest
import Foundation
import SwiftData
@testable import Learn

final class MinDateFetchPerformanceTests: XCTestCase {

    @MainActor
    func testBenchmarkMinDateFetch() async throws {
        let schema = Schema([Stay.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        // Populate with 10,000 stays
        print("Populating 10,000 stays...")
        let calendar = Calendar.current

        // Use a deterministic seed date
        let startDate = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        for i in 0..<10_000 {
            // Distribute stays randomly over ~13 years
            let enteredOn = calendar.date(byAdding: .day, value: Int.random(in: 0...5000), to: startDate)!
            let stay = Stay(
                countryName: "Country \(i)",
                enteredOn: enteredOn
            )
            context.insert(stay)
        }
        try context.save()
        print("Population complete.")

        // Benchmark 1: Fetch All (Current Approach)
        let startTimeAll = Date()
        let descriptorAll = FetchDescriptor<Stay>()
        let allStays = (try? context.fetch(descriptorAll)) ?? []
        let minDateAll = allStays.map { $0.enteredOn }.min()
        let durationAll = Date().timeIntervalSince(startTimeAll)
        print("Fetch All (10,000 items) took: \(durationAll) seconds. Result: \(String(describing: minDateAll))")

        // Benchmark 2: Optimized Approach (Fetch Limit 1 with Sort)
        let startTimeOpt = Date()
        var descriptorOpt = FetchDescriptor<Stay>(sortBy: [SortDescriptor(\.enteredOn, order: .forward)])
        descriptorOpt.fetchLimit = 1
        let optStays = (try? context.fetch(descriptorOpt)) ?? []
        let minDateOpt = optStays.first?.enteredOn
        let durationOpt = Date().timeIntervalSince(startTimeOpt)
        print("Optimized Fetch took: \(durationOpt) seconds. Result: \(String(describing: minDateOpt))")

        // Validation
        XCTAssertEqual(minDateAll, minDateOpt, "Both methods should return the same date")

        // Performance Assertion
        // Note: In an in-memory store with small dataset, the difference might be small,
        // but sorting in database (even in-memory) avoids creating 10,000 objects.
        XCTAssertTrue(durationOpt < durationAll, "Optimized fetch should be faster")
    }
}
