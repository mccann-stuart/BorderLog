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
    }
}
