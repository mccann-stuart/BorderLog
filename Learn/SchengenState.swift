//
//  SchengenState.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import Foundation
import Observation
import SwiftData

@Observable
final class SchengenState {
    var summary: SchengenSummary
    var overlapCount: Int = 0
    var gapDays: Int = 0

    init() {
        // Initialize with safe defaults
        let now = Date()
        // Window start is approximately 180 days ago
        let windowStart = Calendar.current.date(byAdding: .day, value: -179, to: now) ?? now
        self.summary = SchengenSummary(
            usedDays: 0,
            remainingDays: 90,
            overstayDays: 0,
            windowStart: windowStart,
            windowEnd: now
        )
    }

    @MainActor
    func update(modelContext: ModelContext) async {
        let calendar = Calendar.current
        let now = Date()
        // Window start is approximately 2 years ago (730 days) to cover recent history for validation
        // and comfortably include the 180-day Schengen window.
        let windowStart = calendar.date(byAdding: .day, value: -730, to: now) ?? now
        let distantPast = Date.distantPast

        // Fetch relevant stays:
        // - Started on or before now
        // - Ongoing (exitedOn == nil) OR ended after windowStart
        // This avoids fetching and mapping the entire history (O(N)) on the main thread.
        let stayDescriptor = FetchDescriptor<Stay>(
            predicate: #Predicate { stay in
                stay.enteredOn <= now && (stay.exitedOn == nil || (stay.exitedOn ?? distantPast) >= windowStart)
            },
            sortBy: [SortDescriptor(\.enteredOn, order: .reverse)]
        )
        let stays = (try? modelContext.fetch(stayDescriptor)) ?? []

        // Fetch relevant overrides:
        // - Date on or after windowStart
        let overrideDescriptor = FetchDescriptor<DayOverride>(
            predicate: #Predicate { override in
                override.date >= windowStart
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let overrides = (try? modelContext.fetch(overrideDescriptor)) ?? []

        // Extract data on MainActor to avoid accessing SwiftData objects on background thread.
        // Accessing properties of @Model objects must happen on the context's thread (MainActor here).
        let stayInfos = stays.map {
            StayInfo(
                enteredOn: $0.enteredOn,
                exitedOn: $0.exitedOn,
                region: $0.region
            )
        }

        let overrideInfos = overrides.map {
            OverrideInfo(
                date: $0.date,
                region: $0.region
            )
        }

        let result = await Task.detached(priority: .userInitiated) {
            // Optimized: Use reverseSortedStays variants as stayInfos is derived from reverse-sorted @Query
            let (overlapCount, gapDays) = StayValidation.validate(reverseSortedStays: stayInfos, calendar: calendar)
            let summary = SchengenCalculator.summary(for: stayInfos, overrides: overrideInfos, calendar: calendar)

            return (summary, overlapCount, gapDays)
        }.value

        if Task.isCancelled {
            return
        }

        // Update state on MainActor
        self.summary = result.0
        self.overlapCount = result.1
        self.gapDays = result.2
    }
}
