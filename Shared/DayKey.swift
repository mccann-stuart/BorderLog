//
//  DayKey.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation

enum DayKey {
    static let format = "yyyy-MM-dd"

    static func make(from date: Date, timeZone: TimeZone) -> String {
        formatter(for: timeZone).string(from: date)
    }

    static func date(for dayKey: String, timeZone: TimeZone) -> Date? {
        formatter(for: timeZone).date(from: dayKey)
    }

    private static func formatter(for timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }
}
