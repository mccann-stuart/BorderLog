//
//  SampleData.swift
//  Learn
//
//  Created by Jules on 15/02/2026.
//

import Foundation
import SwiftData

struct SampleData {
    @MainActor
    static func seed(context: ModelContext) {
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
            countryCode: "UK",
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

        context.insert(stay1)
        context.insert(stay2)
        context.insert(stay3)

        let overrideDay = DayOverride(
            date: calendar.date(byAdding: .day, value: -15, to: today) ?? today,
            countryName: "Ireland",
            countryCode: "IE",
            region: .nonSchengen,
            notes: "Day trip"
        )
        context.insert(overrideDay)

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
        context.insert(sampleLocation)

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
        context.insert(samplePhoto)

        Task { @MainActor in
            await LedgerRecomputeService.recomputeAll(modelContext: context)
        }
    }
}
