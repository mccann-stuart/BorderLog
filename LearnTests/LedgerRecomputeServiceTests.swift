//
//  LedgerRecomputeServiceTests.swift
//  LearnTests
//
//  Created by Jules on 23/02/2026.
//

import XCTest
import SwiftData
@testable import Learn

@MainActor
final class LedgerRecomputeServiceTests: XCTestCase {

    func testFetchEarliestStayDateReturnsCorrectDate() async throws {
        let schema = Schema([Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let longAgo = Calendar.current.date(byAdding: .day, value: -100, to: now)!

        let stay1 = Stay(countryName: "A", enteredOn: now)
        let stay2 = Stay(countryName: "B", enteredOn: longAgo) // Earliest
        let stay3 = Stay(countryName: "C", enteredOn: yesterday)
        let stay4 = Stay(countryName: "D", enteredOn: tomorrow)

        context.insert(stay1)
        context.insert(stay2)
        context.insert(stay3)
        context.insert(stay4)

        try context.save()

        let service = LedgerRecomputeService(modelContainer: container)

        // This requires fetchEarliestStayDate to be internal, not private
        let earliest = service.fetchEarliestStayDate()

        XCTAssertEqual(earliest, longAgo)
    }

    func testFetchEarliestOverrideDateReturnsCorrectDate() async throws {
        let schema = Schema([Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let now = Date()
        let future = Calendar.current.date(byAdding: .day, value: 10, to: now)!
        let past = Calendar.current.date(byAdding: .day, value: -5, to: now)! // Earliest

        let override1 = DayOverride(date: now, countryName: "A")
        let override2 = DayOverride(date: future, countryName: "B")
        let override3 = DayOverride(date: past, countryName: "C")

        context.insert(override1)
        context.insert(override2)
        context.insert(override3)

        try context.save()

        let service = LedgerRecomputeService(modelContainer: container)

        // This requires fetchEarliestOverrideDate to be internal, not private
        let earliest = service.fetchEarliestOverrideDate()

        XCTAssertEqual(earliest, past)
    }

    func testFetchEarliestDatesReturnNilWhenEmpty() async throws {
        let schema = Schema([Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        let service = LedgerRecomputeService(modelContainer: container)

        XCTAssertNil(service.fetchEarliestStayDate())
        XCTAssertNil(service.fetchEarliestOverrideDate())
    }
}
