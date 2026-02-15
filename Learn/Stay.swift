//
//  Stay.swift
//  Learn
//
//  Created by Mccann Stuart on 13/02/2026.
//

import Foundation
import SwiftData

enum Region: String, CaseIterable, Codable, Identifiable {
    case schengen = "Schengen"
    case nonSchengen = "Non-Schengen"
    case other = "Other"

    var id: String { rawValue }
}

@Model
final class Stay {
    var countryName: String
    var countryCode: String?
    var regionRaw: String
    var enteredOn: Date
    var exitedOn: Date?
    var notes: String

    init(
        countryName: String,
        countryCode: String? = nil,
        region: Region = .schengen,
        enteredOn: Date,
        exitedOn: Date? = nil,
        notes: String = ""
    ) {
        self.countryName = countryName
        self.countryCode = countryCode
        self.regionRaw = region.rawValue
        self.enteredOn = enteredOn
        self.exitedOn = exitedOn
        self.notes = notes
    }

    var region: Region {
        get { Region(rawValue: regionRaw) ?? .other }
        set { regionRaw = newValue.rawValue }
    }

    var isOngoing: Bool {
        exitedOn == nil
    }

    var displayTitle: String {
        let trimmedCode = countryCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedCode.isEmpty {
            return countryName
        }
        return "\(countryName) (\(trimmedCode.uppercased()))"
    }

    func durationInDays(asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: enteredOn)
        let end = calendar.startOfDay(for: exitedOn ?? referenceDate)
        guard end >= start else { return 0 }
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return days + 1
    }
}
