//
//  StayValidation.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import Foundation

enum StayValidation {
    nonisolated static func validate(stays: [StayInfo], calendar: Calendar) -> (overlapCount: Int, gapDays: Int) {
        return calculateValidationMetrics(chronologicalStays: stays.sorted { $0.enteredOn < $1.enteredOn }, calendar: calendar)
    }

    nonisolated static func validate(reverseSortedStays stays: [StayInfo], calendar: Calendar) -> (overlapCount: Int, gapDays: Int) {
        // Optimization: Stays are reverse-sorted by enteredOn (descending).
        // We iterate in reverse to process them in chronological order (ascending),
        // allowing us to merge intervals on-the-fly without an intermediate array or sort.
        assert(zip(stays, stays.dropFirst()).allSatisfy { $0.enteredOn >= $1.enteredOn },
               "StayValidation.validate(reverseSortedStays:) expects stays to be sorted descending by enteredOn")

        return calculateValidationMetrics(chronologicalStays: stays.reversed(), calendar: calendar)
    }

    nonisolated static func overlapCount(stays: [StayInfo], calendar: Calendar) -> Int {
        return validate(stays: stays, calendar: calendar).overlapCount
    }

    nonisolated static func overlapCount(reverseSortedStays stays: [StayInfo], calendar: Calendar) -> Int {
        return validate(reverseSortedStays: stays, calendar: calendar).overlapCount
    }

    nonisolated static func gapDays(stays: [StayInfo], calendar: Calendar) -> Int {
        return validate(stays: stays, calendar: calendar).gapDays
    }

    nonisolated static func gapDays(reverseSortedStays stays: [StayInfo], calendar: Calendar) -> Int {
        return validate(reverseSortedStays: stays, calendar: calendar).gapDays
    }

    @MainActor
    static func validate(stays: [Stay], calendar: Calendar) -> (overlapCount: Int, gapDays: Int) {
        let stayInfos = snapshot(stays: stays)
        return validate(stays: stayInfos, calendar: calendar)
    }

    @MainActor
    static func validate(reverseSortedStays stays: [Stay], calendar: Calendar) -> (overlapCount: Int, gapDays: Int) {
        let stayInfos = snapshot(stays: stays)
        return validate(reverseSortedStays: stayInfos, calendar: calendar)
    }

    @MainActor
    static func overlapCount(stays: [Stay], calendar: Calendar) -> Int {
        return validate(stays: stays, calendar: calendar).overlapCount
    }

    @MainActor
    static func overlapCount(reverseSortedStays stays: [Stay], calendar: Calendar) -> Int {
        return validate(reverseSortedStays: stays, calendar: calendar).overlapCount
    }

    @MainActor
    static func gapDays(stays: [Stay], calendar: Calendar) -> Int {
        return validate(stays: stays, calendar: calendar).gapDays
    }

    @MainActor
    static func gapDays(reverseSortedStays stays: [Stay], calendar: Calendar) -> Int {
        return validate(reverseSortedStays: stays, calendar: calendar).gapDays
    }

    nonisolated private static func calculateValidationMetrics<S: Sequence>(chronologicalStays: S, calendar: Calendar) -> (overlapCount: Int, gapDays: Int) where S.Element == StayInfo {
        var overlapCount = 0
        var gapDays = 0
        var currentEnd: Date?

        for stay in chronologicalStays {
            let start = calendar.startOfDay(for: stay.enteredOn)
            let end = calendar.startOfDay(for: stay.exitedOn ?? Date.distantFuture)

            if let existingEnd = currentEnd {
                if start <= existingEnd {
                    // Overlap
                    overlapCount += 1
                    // Extend the current interval if needed
                    if end > existingEnd {
                        currentEnd = end
                    }
                } else {
                    // Gap
                    // Calculate days between existingEnd and start
                    let dayDiff = calendar.dateComponents([.day], from: existingEnd, to: start).day ?? 0
                    if dayDiff > 1 {
                        gapDays += dayDiff - 1
                    }
                    // Start new interval
                    currentEnd = end
                }
            } else {
                // First stay
                currentEnd = end
            }
        }

        return (overlapCount, gapDays)
    }

    @MainActor
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

    @MainActor
    private static func snapshot(stays: [Stay]) -> [StayInfo] {
        stays.map {
            StayInfo(
                enteredOn: $0.enteredOn,
                exitedOn: $0.exitedOn,
                region: $0.region
            )
        }
    }
}
