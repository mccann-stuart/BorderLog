//
//  DataManager.swift
//  Learn
//
//  Created by Jules on 16/02/2026.
//

import Foundation
import SwiftData
import os

struct DataManager {
    let modelContext: ModelContext
    private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "DataManager")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Deletes the provided model from the context.
    func delete(_ model: any PersistentModel) {
        modelContext.delete(model)
    }

    /// Deletes models at the specified offsets from the provided array.
    func delete<T: PersistentModel>(offsets: IndexSet, from models: [T]) {
        for index in offsets {
            modelContext.delete(models[index])
        }
    }

    /// Resets all data by deleting all entities.
    func resetAllData() throws {
        try modelContext.delete(model: Stay.self)
        try modelContext.delete(model: DayOverride.self)
        try modelContext.delete(model: LocationSample.self)
        try modelContext.delete(model: PhotoSignal.self)
        try modelContext.delete(model: PresenceDay.self)
        try modelContext.delete(model: PhotoIngestState.self)
        Self.logger.info("All data reset.")
    }

    /// Seeds sample data if the store is empty.
    /// Returns true if successful, false if data already exists.
    func seedSampleData() throws -> Bool {
        let stayDescriptor = FetchDescriptor<Stay>()
        let overrideDescriptor = FetchDescriptor<DayOverride>()

        let staysCount = try modelContext.fetchCount(stayDescriptor)
        let overridesCount = try modelContext.fetchCount(overrideDescriptor)

        guard staysCount == 0 && overridesCount == 0 else {
            Self.logger.info("Data already exists. Skipping seed.")
            return false
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let stay1 = Stay(
            countryName: "Portugal",
            countryCode: "PT",
            region: .schengen,
            enteredOn: calendar.date(byAdding: .day, value: -40, to: today) ?? today,
            exitedOn: calendar.date(byAdding: .day, value: -10, to: today) ?? today,
            notes: "Work trip"
        )
        let stay2 = Stay(
            countryName: "United Kingdom",
            countryCode: "GB",
            region: .nonSchengen,
            enteredOn: calendar.date(byAdding: .day, value: -9, to: today) ?? today,
            exitedOn: calendar.date(byAdding: .day, value: -2, to: today) ?? today,
            notes: "Client meetings"
        )
        let stay3 = Stay(
            countryName: "Spain",
            countryCode: "ES",
            region: .schengen,
            enteredOn: calendar.date(byAdding: .day, value: -1, to: today) ?? today,
            exitedOn: nil,
            notes: "Current"
        )

        modelContext.insert(stay1)
        modelContext.insert(stay2)
        modelContext.insert(stay3)

        let overrideDay = DayOverride(
            date: calendar.date(byAdding: .day, value: -15, to: today) ?? today,
            countryName: "Ireland",
            countryCode: "IE",
            region: .nonSchengen,
            notes: "Day trip"
        )
        modelContext.insert(overrideDay)

        let sampleLocationTimestamp = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let sampleLocation = LocationSample(
            timestamp: sampleLocationTimestamp,
            latitude: 40.4168,
            longitude: -3.7038,
            accuracyMeters: 65,
            source: .app,
            timeZoneId: TimeZone.current.identifier,
            dayKey: DayKey.make(from: sampleLocationTimestamp, timeZone: TimeZone.current),
            countryCode: "ES",
            countryName: "Spain"
        )
        modelContext.insert(sampleLocation)

        let samplePhotoTimestamp = calendar.date(byAdding: .day, value: -20, to: today) ?? today
        let samplePhoto = PhotoSignal(
            timestamp: samplePhotoTimestamp,
            latitude: 48.8566,
            longitude: 2.3522,
            assetIdHash: UUID().uuidString,
            timeZoneId: TimeZone.current.identifier,
            dayKey: DayKey.make(from: samplePhotoTimestamp, timeZone: TimeZone.current),
            countryCode: "FR",
            countryName: "France"
        )
        modelContext.insert(samplePhoto)

        let container = modelContext.container
        Task {
            let recomputeService = LedgerRecomputeService(modelContainer: container)
            await recomputeService.recomputeAll()
        }

        Self.logger.info("Sample data seeded.")
        return true
    }
}
