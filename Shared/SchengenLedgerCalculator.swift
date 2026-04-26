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
    private nonisolated static let windowSize = 180
    private nonisolated static let maxAllowedDays = 90

    nonisolated static func summary(
        for days: [PresenceDay],
        asOf referenceDate: Date = Date(),
        calendar: Calendar = .current,
        isReverseSorted: Bool = false,
        countingMode: CountryDayCountingMode = .resolvedCountry
    ) -> SchengenLedgerSummary {
        let windowEnd = calendar.startOfDay(for: referenceDate)
        let windowStart = calendar.date(byAdding: .day, value: -(windowSize - 1), to: windowEnd) ?? windowEnd

        var schengenDays = 0
        var knownDays = 0

        // Optimization: Replace multiple .filter() calls (which create intermediate arrays)
        // with a single pass through the sequence.
        for day in days {
            // ⚡ Bolt: Explicitly handle pre-sorted data (like from @Query) to allow early loop termination,
            // dropping evaluation from O(N) to O(W) where W is the bounded window.
            if isReverseSorted {
                if day.date > windowEnd { continue }
                if day.date < windowStart { break }
            }

            if day.date >= windowStart && day.date <= windowEnd {
                let countedCountries = day.countedCountries(for: countingMode)
                if !countedCountries.isEmpty {
                    knownDays += 1
                    if countedCountries.contains(where: \.isSchengen) {
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
