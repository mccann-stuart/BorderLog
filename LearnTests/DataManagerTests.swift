//
//  DataManagerTests.swift
//  LearnTests
//
//  Created by Jules on 16/02/2026.
//

import XCTest
@testable import Learn
import SwiftData
import Foundation

@MainActor
final class DataManagerTests: XCTestCase {

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

    func testSeedSampleDataInsertsData() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let dataManager = DataManager(modelContext: context)

        // Seed
        let seeded = try dataManager.seedSampleData()

        XCTAssertTrue(seeded)

        // Verify counts
        let stayDescriptor = FetchDescriptor<Stay>()
        let overrideDescriptor = FetchDescriptor<DayOverride>()
        let locationDescriptor = FetchDescriptor<LocationSample>()
        let photoDescriptor = FetchDescriptor<PhotoSignal>()

        let staysCount = try context.fetchCount(stayDescriptor)
        let overridesCount = try context.fetchCount(overrideDescriptor)
        let locationsCount = try context.fetchCount(locationDescriptor)
        let photosCount = try context.fetchCount(photoDescriptor)

        XCTAssertTrue(staysCount == 3)
        XCTAssertTrue(overridesCount == 1)
        XCTAssertTrue(locationsCount == 1)
        XCTAssertTrue(photosCount == 1)

        // Seed again should fail
        let seededAgain = try dataManager.seedSampleData()
        XCTAssertTrue(!seededAgain)
    }

    func testResetAllDataRemovesData() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let dataManager = DataManager(modelContext: context)

        // Seed first
        _ = try dataManager.seedSampleData()

        // Verify data exists
        let stayDescriptor = FetchDescriptor<Stay>()
        let staysCountBefore = try context.fetchCount(stayDescriptor)
        XCTAssertTrue(staysCountBefore > 0)

        // Additional entities should also be removed by a full reset.
        let calendarDay = DayKey.make(from: Date(), timeZone: .current)
        let calendarSignal = CalendarSignal(
            timestamp: Date(),
            dayKey: calendarDay,
            latitude: 51.5074,
            longitude: -0.1278,
            countryCode: "GB",
            countryName: "United Kingdom",
            timeZoneId: TimeZone.current.identifier,
            eventIdentifier: "event-id-1",
            title: "Flight",
            source: "Calendar"
        )
        let countryConfig = CountryConfig(countryCode: "GB", maxAllowedDays: 180)
        context.insert(calendarSignal)
        context.insert(countryConfig)
        try context.save()

        // Reset
        try dataManager.resetAllData()

        // Verify empty
        let staysCountAfter = try context.fetchCount(stayDescriptor)
        let overridesCountAfter = try context.fetchCount(FetchDescriptor<DayOverride>())
        let locationsCountAfter = try context.fetchCount(FetchDescriptor<LocationSample>())
        let photosCountAfter = try context.fetchCount(FetchDescriptor<PhotoSignal>())
        let calendarCountAfter = try context.fetchCount(FetchDescriptor<CalendarSignal>())
        let presenceCountAfter = try context.fetchCount(FetchDescriptor<PresenceDay>())
        let ingestStateCountAfter = try context.fetchCount(FetchDescriptor<PhotoIngestState>())
        let countryConfigCountAfter = try context.fetchCount(FetchDescriptor<CountryConfig>())

        XCTAssertTrue(staysCountAfter == 0)
        XCTAssertTrue(overridesCountAfter == 0)
        XCTAssertTrue(locationsCountAfter == 0)
        XCTAssertTrue(photosCountAfter == 0)
        XCTAssertTrue(calendarCountAfter == 0)
        XCTAssertTrue(presenceCountAfter == 0)
        XCTAssertTrue(ingestStateCountAfter == 0)
        XCTAssertTrue(countryConfigCountAfter == 0)
    }

    func testDeleteRemovesSpecificModel() async throws {
        let container = try makeContainer()
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
        XCTAssertTrue(staysCount == 0)
    }
}
