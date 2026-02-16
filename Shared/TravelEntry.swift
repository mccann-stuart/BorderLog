//
//  TravelEntry.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import Foundation

enum Region: String, CaseIterable, Codable, Identifiable {
    case schengen = "Schengen"
    case nonSchengen = "Non-Schengen"
    case other = "Other"

    var id: String { rawValue }
}

protocol TravelEntry: AnyObject {
    var countryName: String { get }
    var countryCode: String? { get }
    var regionRaw: String { get set }
}

extension TravelEntry {
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
