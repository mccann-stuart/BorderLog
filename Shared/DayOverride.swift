//
//  DayOverride.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import Foundation
import SwiftData

@Model
nonisolated final class DayOverride: TravelEntry {
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

}

extension DayOverride: SchengenOverride {}
