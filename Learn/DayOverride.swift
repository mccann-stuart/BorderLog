//
//  DayOverride.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import Foundation
import SwiftData

@Model
final class DayOverride {
    var date: Date
    var countryName: String
    var countryCode: String?
    var regionRaw: String
    var notes: String

    init(
        date: Date,
        countryName: String,
        countryCode: String? = nil,
        region: Region = .schengen,
        notes: String = ""
    ) {
        self.date = date
        self.countryName = countryName
        self.countryCode = countryCode
        self.regionRaw = region.rawValue
        self.notes = notes
    }

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
