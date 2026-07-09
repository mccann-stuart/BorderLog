//
//  SchengenCalculator.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import Foundation

struct SchengenSummary: Sendable {
    let usedDays: Int
    let remainingDays: Int
    let overstayDays: Int
    let windowStart: Date
    let windowEnd: Date
}

enum SchengenCalculator {
    nonisolated private static let windowSize = 180
    nonisolated private static let maxAllowedDays = 90

    private struct Interval {
        let start: Date
        var end: Date
    }

    nonisolated static func summary(
        for stays: [StayInfo],
        overrides: [OverrideInfo] = [],
        asOf referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> SchengenSummary {
        let windowEnd = calendar.startOfDay(for: referenceDate)
        let windowStart = calendar.date(byAdding: .day, value: -(windowSize - 1), to: windowEnd) ?? windowEnd

        // --- 1. Collect and Merge Intervals ---
        var mergedIntervals: [Interval] = []

        // Callers normally provide reverse-sorted SwiftData rows. Keep that contract check,
        // but sort again after civil-day normalization: absolute Date ordering can invert
        // across the International Date Line even when the stored day keys are consecutive.
        assert(zip(stays, stays.dropFirst()).allSatisfy { $0.enteredOn >= $1.enteredOn },
               "SchengenCalculator.summary expects stays to be sorted descending by enteredOn")

        let normalizedIntervals = stays.compactMap { stay -> Interval? in
            guard stay.region == .schengen else { return nil }
            let stayStart = normalizedDate(
                dayKey: stay.entryDayKey,
                fallback: stay.enteredOn,
                calendar: calendar
            )
            let stayEnd = stay.exitDayKey.flatMap { DayKey.date(for: $0, timeZone: calendar.timeZone) }
                ?? calendar.startOfDay(for: stay.exitedOn ?? referenceDate)

            // Skip if out of window
            if stayEnd < windowStart || stayStart > windowEnd {
                return nil
            }

            let clampedStart = max(stayStart, windowStart)
            let clampedEnd = min(stayEnd, windowEnd)
            guard clampedStart <= clampedEnd else { return nil }
            return Interval(start: clampedStart, end: clampedEnd)
        }.sorted { lhs, rhs in
            if lhs.start == rhs.start {
                return lhs.end < rhs.end
            }
            return lhs.start < rhs.start
        }

        for interval in normalizedIntervals {
            if let lastInterval = mergedIntervals.last {
                // Check for overlap or adjacency
                // Since we process in order, new start >= last start.
                // We just check if new start <= last end + 1 day.
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: lastInterval.end),
                   nextDay >= interval.start {
                    // Merge if overlapping or adjacent
                    if interval.end > lastInterval.end {
                        mergedIntervals[mergedIntervals.count - 1].end = interval.end
                    }
                } else {
                    mergedIntervals.append(interval)
                }
            } else {
                mergedIntervals.append(interval)
            }
        }

        // Calculate initial used days from merged intervals
        var usedDays = 0
        for interval in mergedIntervals {
            let days = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
            usedDays += (days + 1)
        }

        // --- 2. Handle Overrides ---

        // Map: Date -> Region (last one wins)
        var overrideMap: [Date: Region] = [:]
        for overrideDay in overrides {
            let day = normalizedDate(
                dayKey: overrideDay.dayKey,
                fallback: overrideDay.date,
                calendar: calendar
            )
            if day >= windowStart && day <= windowEnd {
                overrideMap[day] = overrideDay.region
            }
        }

        // Adjust count based on overrides
        for (day, region) in overrideMap {
            // Check if day is covered by any interval
            var isCovered = false
            for interval in mergedIntervals {
                if day >= interval.start && day <= interval.end {
                    isCovered = true
                    break
                }
                if interval.start > day { break } // Optimization: mergedIntervals is sorted
            }

            if region == .schengen {
                if !isCovered {
                    usedDays += 1
                }
            } else { // Non-Schengen (removes)
                if isCovered {
                    usedDays -= 1
                }
            }
        }

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

    nonisolated private static func normalizedDate(
        dayKey: String?,
        fallback: Date,
        calendar: Calendar
    ) -> Date {
        // Day keys preserve the user's selected civil date when the calculation calendar
        // differs from the time zone in which SwiftData normalized the stored Date.
        if let dayKey,
           let normalizedDate = DayKey.date(for: dayKey, timeZone: calendar.timeZone) {
            return normalizedDate
        }
        return calendar.startOfDay(for: fallback)
    }

    @MainActor
    static func summary(
        for stays: [Stay],
        overrides: [DayOverride] = [],
        asOf referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> SchengenSummary {
        let stayInfos = stays.map {
            StayInfo(
                enteredOn: $0.enteredOn,
                exitedOn: $0.exitedOn,
                region: $0.region,
                entryDayKey: $0.entryDayKey,
                exitDayKey: $0.exitDayKey
            )
        }
        let overrideInfos = overrides.map {
            OverrideInfo(
                date: $0.date,
                region: $0.region,
                dayKey: $0.dayKey
            )
        }

        return summary(for: stayInfos, overrides: overrideInfos, asOf: referenceDate, calendar: calendar)
    }
}
