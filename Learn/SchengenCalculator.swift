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

    private struct Interval {
        let start: Date
        var end: Date
    }

    static func summary(
        for stays: [Stay],
        overrides: [DayOverride] = [],
        asOf referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> SchengenSummary {
        let windowEnd = calendar.startOfDay(for: referenceDate)
        let windowStart = calendar.date(byAdding: .day, value: -(windowSize - 1), to: windowEnd) ?? windowEnd

        // --- 1. Collect and Merge Intervals ---
        var intervals: [Interval] = []

        for stay in stays where stay.region == .schengen {
            let stayStart = calendar.startOfDay(for: stay.enteredOn)
            let stayEnd = calendar.startOfDay(for: stay.exitedOn ?? referenceDate)

            // Skip if out of window
            if stayEnd < windowStart || stayStart > windowEnd {
                continue
            }

            let clampedStart = max(stayStart, windowStart)
            let clampedEnd = min(stayEnd, windowEnd)

            if clampedStart <= clampedEnd {
                intervals.append(Interval(start: clampedStart, end: clampedEnd))
            }
        }

        // Sort intervals by start date
        intervals.sort { $0.start < $1.start }

        var mergedIntervals: [Interval] = []
        for interval in intervals {
            if mergedIntervals.isEmpty {
                mergedIntervals.append(interval)
            } else {
                // Check for overlap or adjacency
                let lastIndex = mergedIntervals.count - 1
                let lastEnd = mergedIntervals[lastIndex].end

                // Calculate next day after lastEnd to check adjacency
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: lastEnd),
                   nextDay >= interval.start {
                    // Merge if overlapping or adjacent
                    if interval.end > lastEnd {
                        mergedIntervals[lastIndex].end = interval.end
                    }
                } else {
                    mergedIntervals.append(interval)
                }
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
            let day = calendar.startOfDay(for: overrideDay.date)
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
}
