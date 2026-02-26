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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        guard let y = components.year, let m = components.month, let d = components.day else {
            return formatter(for: timeZone).string(from: date)
        }

        return "\(y)-\(m < 10 ? "0" : "")\(m)-\(d < 10 ? "0" : "")\(d)"
    }

    static func date(for dayKey: String, timeZone: TimeZone) -> Date? {
        let parts = dayKey.split(separator: "-")
        if parts.count == 3,
           let y = Int(parts[0]),
           let m = Int(parts[1]),
           let d = Int(parts[2]) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let components = DateComponents(year: y, month: m, day: d)
            return calendar.date(from: components)
        }
        return formatter(for: timeZone).date(from: dayKey)
    }

    private static func formatter(for timeZone: TimeZone) -> DateFormatter {
        let key = "DayKeyFormatter_" + timeZone.identifier
        let dictionary = Thread.current.threadDictionary

        if let formatter = dictionary[key] as? DateFormatter {
            return formatter
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format

        dictionary[key] = formatter
        return formatter
    }
}
