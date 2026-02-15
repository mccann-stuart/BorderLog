//
//  DataManagerTests.swift
//  LearnTests
//
//  Created by Jules on 16/02/2026.
//

import Testing
@testable import Learn
import SwiftData
import Foundation

struct DataManagerTests {

    @Test func seedSampleDataInsertsData() async throws {
        let schema = Schema([Stay.self, DayOverride.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let dataManager = DataManager(modelContext: context)

        // Seed
        let seeded = try dataManager.seedSampleData()

        #expect(seeded)

        // Verify counts
        let stayDescriptor = FetchDescriptor<Stay>()
        let overrideDescriptor = FetchDescriptor<DayOverride>()

        let staysCount = try context.fetchCount(stayDescriptor)
        let overridesCount = try context.fetchCount(overrideDescriptor)

        #expect(staysCount == 3)
        #expect(overridesCount == 1)

        // Seed again should fail
        let seededAgain = try dataManager.seedSampleData()
        #expect(!seededAgain)
    }

    @Test func resetAllDataRemovesData() async throws {
        let schema = Schema([Stay.self, DayOverride.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let dataManager = DataManager(modelContext: context)

        // Seed first
        _ = try dataManager.seedSampleData()

        // Verify data exists
        let stayDescriptor = FetchDescriptor<Stay>()
        let staysCountBefore = try context.fetchCount(stayDescriptor)
        #expect(staysCountBefore > 0)

        // Reset
        try dataManager.resetAllData()

        // Verify empty
        let staysCountAfter = try context.fetchCount(stayDescriptor)
        let overridesCountAfter = try context.fetchCount(FetchDescriptor<DayOverride>())

        #expect(staysCountAfter == 0)
        #expect(overridesCountAfter == 0)
    }

    @Test func deleteRemovesSpecificModel() async throws {
        let schema = Schema([Stay.self, DayOverride.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let dataManager = DataManager(modelContext: context)

        let stay = Stay(
            countryName: "Test",
            countryCode: "TC",
            region: .schengen,
            enteredOn: Date(),
            exitedOn: nil,
            notes: "Test stay"
        )
        context.insert(stay)

        try context.save()

        dataManager.delete(stay)

        let staysCount = try context.fetchCount(FetchDescriptor<Stay>())
        #expect(staysCount == 0)
    }
}
