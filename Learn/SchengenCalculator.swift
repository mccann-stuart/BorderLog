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
    private static let windowSize = 180
    private static let maxAllowedDays = 90

    private struct Interval {
        let start: Date
        var end: Date
    }

    static func summary<S: SchengenStay, O: SchengenOverride>(
        for stays: [S],
        overrides: [O] = [],
        asOf referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> SchengenSummary {
        let windowEnd = calendar.startOfDay(for: referenceDate)
        let windowStart = calendar.date(byAdding: .day, value: -(windowSize - 1), to: windowEnd) ?? windowEnd

        // --- 1. Collect and Merge Intervals ---
        var mergedIntervals: [Interval] = []

        // Optimization: Stays are typically reverse-sorted by enteredOn (descending) from the query.
        // We iterate in reverse to process them in chronological order (ascending),
        // allowing us to merge intervals on-the-fly without an intermediate array or sort.
        assert(zip(stays, stays.dropFirst()).allSatisfy { $0.enteredOn >= $1.enteredOn },
               "SchengenCalculator.summary expects stays to be sorted descending by enteredOn")

        for stay in stays.reversed() where stay.region == .schengen {
            let stayStart = calendar.startOfDay(for: stay.enteredOn)
            let stayEnd = calendar.startOfDay(for: stay.exitedOn ?? referenceDate)

            // Skip if out of window
            if stayEnd < windowStart || stayStart > windowEnd {
                continue
            }

            let clampedStart = max(stayStart, windowStart)
            let clampedEnd = min(stayEnd, windowEnd)

            guard clampedStart <= clampedEnd else { continue }

            if let lastInterval = mergedIntervals.last {
                // Check for overlap or adjacency
                // Since we process in order, new start >= last start.
                // We just check if new start <= last end + 1 day.
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: lastInterval.end),
                   nextDay >= clampedStart {
                    // Merge if overlapping or adjacent
                    if clampedEnd > lastInterval.end {
                        mergedIntervals[mergedIntervals.count - 1].end = clampedEnd
                    }
                } else {
                    mergedIntervals.append(Interval(start: clampedStart, end: clampedEnd))
                }
            } else {
                mergedIntervals.append(Interval(start: clampedStart, end: clampedEnd))
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
