//
//  Stay.swift
//  Learn
//
//  Created by Mccann Stuart on 13/02/2026.
//

import Foundation
import SwiftData

@Model
final class Stay {
    var countryName: String
    var countryCode: String?
    var dayTimeZoneId: String
    var entryDayKey: String
    var exitDayKey: String?
    var regionRaw: String
    var enteredOn: Date
    var exitedOn: Date?
    var notes: String

    init(
        countryName: String,
        countryCode: String? = nil,
        dayTimeZoneId: String? = nil,
        entryDayKey: String? = nil,
        exitDayKey: String? = nil,
        region: Region = .schengen,
        enteredOn: Date,
        exitedOn: Date? = nil,
        notes: String = ""
    ) {
        let timeZone = DayIdentity.canonicalTimeZone(preferredTimeZoneId: dayTimeZoneId)
        let entryIdentity: (dayKey: String, dayTimeZoneId: String, normalizedDate: Date)
        if let entryDayKey {
            entryIdentity = (
                dayKey: entryDayKey,
                dayTimeZoneId: timeZone.identifier,
                normalizedDate: DayKey.date(for: entryDayKey, timeZone: timeZone) ?? enteredOn
            )
        } else {
            entryIdentity = DayIdentity.canonicalDay(
                for: enteredOn,
                preferredTimeZoneId: timeZone.identifier,
                fallback: timeZone
            )
        }

        let normalizedExitedOn: Date?
        let resolvedExitDayKey: String?
        if let exitedOn {
            if let exitDayKey {
                normalizedExitedOn = DayKey.date(for: exitDayKey, timeZone: timeZone) ?? exitedOn
                resolvedExitDayKey = exitDayKey
            } else {
                let exitIdentity = DayIdentity.canonicalDay(
                    for: exitedOn,
                    preferredTimeZoneId: timeZone.identifier,
                    fallback: timeZone
                )
                normalizedExitedOn = exitIdentity.normalizedDate
                resolvedExitDayKey = exitIdentity.dayKey
            }
        } else {
            normalizedExitedOn = nil
            resolvedExitDayKey = nil
        }

        self.countryName = countryName
        self.countryCode = countryCode
        self.dayTimeZoneId = entryIdentity.dayTimeZoneId
        self.entryDayKey = entryIdentity.dayKey
        self.exitDayKey = resolvedExitDayKey
        self.regionRaw = region.rawValue
        self.enteredOn = entryIdentity.normalizedDate
        self.exitedOn = normalizedExitedOn
        self.notes = notes
    }

    var isOngoing: Bool {
        exitedOn == nil
    }

    func durationInDays(asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: enteredOn)
        let end = calendar.startOfDay(for: exitedOn ?? referenceDate)
        guard end >= start else { return 0 }
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return days + 1
    }
}

extension Stay: SchengenStay {}

extension Stay {
    var region: Region {
        get { Region(rawValue: regionRaw) ?? .other }
        set { regionRaw = newValue.rawValue }
    }

    var displayTitle: String {
        let trimmedCode = countryCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedCode.isEmpty {
            return countryName
        }
        return "\(countryName) (\(trimmedCode.uppercased()))"
    }
}
