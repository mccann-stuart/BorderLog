//
//  SchengenState.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import Foundation
import Observation

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
    func update(stays: [Stay], overrides: [DayOverride]) async {
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

        let calendar = Calendar.current
        let result = await Task.detached(priority: .userInitiated) {
            // Optimized: Use reverseSortedStays variants as stayInfos is derived from reverse-sorted @Query
            let overlapCount = await StayValidation.overlapCount(reverseSortedStays: stayInfos, calendar: calendar)
            let gapDays = await StayValidation.gapDays(reverseSortedStays: stayInfos, calendar: calendar)
            let summary = await SchengenCalculator.summary(for: stayInfos, overrides: overrideInfos, calendar: calendar)

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
