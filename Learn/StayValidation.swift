//
//  StayValidation.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import Foundation

enum StayValidation {
    static func overlapCount<S: SchengenStay>(stays: [S], calendar: Calendar) -> Int {
        return calculateOverlapCount(chronologicalStays: stays.sorted { $0.enteredOn < $1.enteredOn }, calendar: calendar)
    }

    static func overlapCount<S: SchengenStay>(reverseSortedStays stays: [S], calendar: Calendar) -> Int {
        // Optimization: Stays are reverse-sorted by enteredOn (descending).
        // We iterate in reverse to process them in chronological order (ascending),
        // allowing us to merge intervals on-the-fly without an intermediate array or sort.
        assert(zip(stays, stays.dropFirst()).allSatisfy { $0.enteredOn >= $1.enteredOn },
               "StayValidation.overlapCount(reverseSortedStays:) expects stays to be sorted descending by enteredOn")

        return calculateOverlapCount(chronologicalStays: stays.reversed(), calendar: calendar)
    }

    static func gapDays<S: SchengenStay>(stays: [S], calendar: Calendar) -> Int {
        return calculateGapDays(chronologicalStays: stays.sorted { $0.enteredOn < $1.enteredOn }, calendar: calendar)
    }

    static func gapDays<S: SchengenStay>(reverseSortedStays stays: [S], calendar: Calendar) -> Int {
        // Optimization: Input must be reverse-sorted (descending).
        // Use reversed() for O(1) reordering.
        assert(zip(stays, stays.dropFirst()).allSatisfy { $0.enteredOn >= $1.enteredOn },
               "StayValidation.gapDays(reverseSortedStays:) expects stays to be sorted descending by enteredOn")

        return calculateGapDays(chronologicalStays: stays.reversed(), calendar: calendar)
    }

    private static func calculateOverlapCount<S: Sequence>(chronologicalStays: S, calendar: Calendar) -> Int where S.Element: SchengenStay {
        var overlapCount = 0
        var currentEnd: Date?

        for stay in chronologicalStays {
            let start = calendar.startOfDay(for: stay.enteredOn)
            let end = calendar.startOfDay(for: stay.exitedOn ?? Date.distantFuture)

            if let existingEnd = currentEnd, start <= existingEnd {
                overlapCount += 1
                currentEnd = max(existingEnd, end)
            } else {
                currentEnd = end
            }
        }

        return overlapCount
    }

    private static func calculateGapDays<C: Collection>(chronologicalStays: C, calendar: Calendar) -> Int where C.Element: SchengenStay {
        guard chronologicalStays.count > 1 else { return 0 }

        var gapDays = 0
        guard let firstStay = chronologicalStays.first else { return 0 }

        // Use distantFuture to represent ongoing stay, ensuring no gap is calculated after it
        var previousEnd = calendar.startOfDay(for: firstStay.exitedOn ?? Date.distantFuture)

        for stay in chronologicalStays.dropFirst() {
            let start = calendar.startOfDay(for: stay.enteredOn)
            if start > previousEnd {
                let dayDiff = calendar.dateComponents([.day], from: previousEnd, to: start).day ?? 0
                if dayDiff > 1 {
                    gapDays += dayDiff - 1
                }
            }

            let end = calendar.startOfDay(for: stay.exitedOn ?? Date.distantFuture)
            if end > previousEnd {
                previousEnd = end
            }
        }

        return gapDays
    }

    static func overlappingStays(
        enteredOn: Date,
        exitedOn: Date?,
        stays: [Stay],
        excluding currentStay: Stay?,
        calendar: Calendar
    ) -> [Stay] {
        let newStart = calendar.startOfDay(for: enteredOn)
        let newEnd = calendar.startOfDay(for: exitedOn ?? Date.distantFuture)
        let newRange = newStart...newEnd

        return stays.filter { stay in
            if let currentStay, stay === currentStay {
                return false
            }
            let stayStart = calendar.startOfDay(for: stay.enteredOn)
            let stayEnd = calendar.startOfDay(for: stay.exitedOn ?? Date.distantFuture)
            let stayRange = stayStart...stayEnd
            return stayRange.overlaps(newRange)
        }
    }
}
