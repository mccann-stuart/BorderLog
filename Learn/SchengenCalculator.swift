//
//  SchengenCalculator.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import Foundation

struct SchengenSummary {
    let usedDays: Int
    let remainingDays: Int
    let overstayDays: Int
    let windowStart: Date
    let windowEnd: Date
}

enum SchengenCalculator {
    private static let windowSize = 180
    private static let maxAllowedDays = 90

    static func summary(
        for stays: [Stay],
        overrides: [DayOverride] = [],
        asOf referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> SchengenSummary {
        let windowEnd = calendar.startOfDay(for: referenceDate)
        let windowStart = calendar.date(byAdding: .day, value: -(windowSize - 1), to: windowEnd) ?? windowEnd
        var uniqueDays = Set<Date>()

        for stay in stays where stay.region == .schengen {
            let stayStart = calendar.startOfDay(for: stay.enteredOn)
            let stayEnd = calendar.startOfDay(for: stay.exitedOn ?? referenceDate)
            if stayEnd < windowStart || stayStart > windowEnd {
                continue
            }

            let clampedStart = max(stayStart, windowStart)
            let clampedEnd = min(stayEnd, windowEnd)
            var day = clampedStart

            while day <= clampedEnd {
                uniqueDays.insert(day)
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = nextDay
            }
        }

        for overrideDay in overrides {
            let day = calendar.startOfDay(for: overrideDay.date)
            if day < windowStart || day > windowEnd {
                continue
            }

            if overrideDay.region == .schengen {
                uniqueDays.insert(day)
            } else {
                uniqueDays.remove(day)
            }
        }

        let usedDays = uniqueDays.count
        let remainingDays = max(0, maxAllowedDays - usedDays)
        let overstayDays = max(0, usedDays - maxAllowedDays)

        return SchengenSummary(
            usedDays: usedDays,
            remainingDays: remainingDays,
            overstayDays: overstayDays,
            windowStart: windowStart,
            windowEnd: windowEnd
        )
    }
}
