//
//  SchengenLedgerCalculator.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation

struct SchengenLedgerSummary: Sendable {
    let usedDays: Int
    let remainingDays: Int
    let overstayDays: Int
    let unknownDays: Int
    let windowStart: Date
    let windowEnd: Date
}

enum SchengenLedgerCalculator {
    private static let windowSize = 180
    private static let maxAllowedDays = 90

    static func summary(
        for days: [PresenceDay],
        asOf referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> SchengenLedgerSummary {
        let windowEnd = calendar.startOfDay(for: referenceDate)
        let windowStart = calendar.date(byAdding: .day, value: -(windowSize - 1), to: windowEnd) ?? windowEnd

        var schengenDays = 0
        var knownDays = 0

        // Optimization: Replace multiple .filter() calls (which create intermediate arrays)
        // with a single pass through the sequence.
        for day in days {
            if day.date >= windowStart && day.date <= windowEnd {
                if day.countryCode != nil || day.countryName != nil {
                    knownDays += 1
                    if let code = day.countryCode, SchengenMembers.isMember(code) {
                        schengenDays += 1
                    }
                }
            }
        }

        let totalDays = windowSize
        let unknownDays = max(0, totalDays - knownDays)

        let remainingDays = max(0, maxAllowedDays - schengenDays)
        let overstayDays = max(0, schengenDays - maxAllowedDays)

        return SchengenLedgerSummary(
            usedDays: schengenDays,
            remainingDays: remainingDays,
            overstayDays: overstayDays,
            unknownDays: unknownDays,
            windowStart: windowStart,
            windowEnd: windowEnd
        )
    }
}
