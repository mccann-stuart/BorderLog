//
//  DayOverrideValidation.swift
//  Learn
//
//  Created by Jules on 16/02/2026.
//

import Foundation

enum DayOverrideValidation {
    static func conflictingOverride(
        forDayKey dayKey: String,
        in overrides: [DayOverride],
        excluding currentOverride: DayOverride? = nil
    ) -> DayOverride? {
        return overrides.first { overrideDay in
            if let currentOverride, overrideDay === currentOverride {
                return false
            }
            return overrideDay.dayKey == dayKey
        }
    }

    /// Checks for a conflicting override in the given list of overrides.
    ///
    /// - Parameters:
    ///   - date: The date to check for conflicts.
    ///   - overrides: The list of existing overrides.
    ///   - currentOverride: An optional override to exclude from the check (e.g., when editing an existing override).
    ///   - calendar: The calendar to use for date comparisons.
    /// - Returns: The conflicting `DayOverride` if found, otherwise `nil`.
    static func conflictingOverride(
        for date: Date,
        in overrides: [DayOverride],
        excluding currentOverride: DayOverride? = nil,
        calendar: Calendar = .current
    ) -> DayOverride? {
        let dayKey = DayKey.make(from: date, timeZone: calendar.timeZone)
        return conflictingOverride(
            forDayKey: dayKey,
            in: overrides,
            excluding: currentOverride
        )
    }
}
