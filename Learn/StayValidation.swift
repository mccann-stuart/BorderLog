//
//  StayValidation.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import Foundation

enum StayValidation {
    static func overlapCount(stays: [Stay], calendar: Calendar) -> Int {
        let sorted = stays.sorted { $0.enteredOn < $1.enteredOn }
        var overlapCount = 0
        var currentEnd: Date?

        for stay in sorted {
            let start = calendar.startOfDay(for: stay.enteredOn)
            let end = calendar.startOfDay(for: stay.exitedOn ?? Date.distantFuture)

            if let currentEnd, start <= currentEnd {
                overlapCount += 1
                currentEnd = max(currentEnd, end)
            } else {
                currentEnd = end
            }
        }

        return overlapCount
    }

    static func gapDays(stays: [Stay], calendar: Calendar) -> Int {
        let sorted = stays.sorted { $0.enteredOn < $1.enteredOn }
        guard sorted.count > 1 else { return 0 }

        var gapDays = 0
        var previousEnd = calendar.startOfDay(for: sorted[0].exitedOn ?? sorted[0].enteredOn)

        for stay in sorted.dropFirst() {
            let start = calendar.startOfDay(for: stay.enteredOn)
            if start > previousEnd {
                let dayDiff = calendar.dateComponents([.day], from: previousEnd, to: start).day ?? 0
                if dayDiff > 1 {
                    gapDays += dayDiff - 1
                }
            }

            let end = calendar.startOfDay(for: stay.exitedOn ?? stay.enteredOn)
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
