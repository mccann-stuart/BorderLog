//
//  DayIdentity.swift
//  Learn
//
//  Created by Codex on 04/03/2026.
//

import Foundation

enum DayIdentity {
    static func canonicalTimeZone(
        preferredTimeZoneId: String?,
        fallback: TimeZone = .current
    ) -> TimeZone {
        if let preferredTimeZoneId,
           let timeZone = TimeZone(identifier: preferredTimeZoneId) {
            return timeZone
        }
        return fallback
    }

    static func canonicalDay(
        for date: Date,
        preferredTimeZoneId: String? = nil,
        fallback: TimeZone = .current
    ) -> (dayKey: String, dayTimeZoneId: String, normalizedDate: Date) {
        let timeZone = canonicalTimeZone(preferredTimeZoneId: preferredTimeZoneId, fallback: fallback)
        let dayKey = DayKey.make(from: date, timeZone: timeZone)
        let normalizedDate = DayKey.date(for: dayKey, timeZone: timeZone) ?? date
        return (dayKey: dayKey, dayTimeZoneId: timeZone.identifier, normalizedDate: normalizedDate)
    }

    static func normalizedDate(
        for dayKey: String,
        dayTimeZoneId: String?,
        fallback: TimeZone = .current
    ) -> Date {
        let timeZone = canonicalTimeZone(preferredTimeZoneId: dayTimeZoneId, fallback: fallback)
        return DayKey.date(for: dayKey, timeZone: timeZone) ?? Date()
    }

    static func dayWindow(
        dayKey: String,
        dayTimeZoneId: String?,
        fallback: TimeZone = .current
    ) -> (start: Date, end: Date, timeZone: TimeZone) {
        let timeZone = canonicalTimeZone(preferredTimeZoneId: dayTimeZoneId, fallback: fallback)
        let start = DayKey.date(for: dayKey, timeZone: timeZone) ?? Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start: start, end: end, timeZone: timeZone)
    }
}
