//
//  LocationSample.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import SwiftData

enum LocationSampleSource: String, Codable, CaseIterable {
    case widget
    case app
}

@Model
nonisolated final class LocationSample {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var accuracyMeters: Double
    var sourceRaw: String
    var timeZoneId: String?
    var dayKey: String
    var countryCode: String?
    var countryName: String?

    init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        accuracyMeters: Double,
        source: LocationSampleSource,
        timeZoneId: String?,
        dayKey: String,
        countryCode: String?,
        countryName: String?
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.accuracyMeters = accuracyMeters
        self.sourceRaw = source.rawValue
        self.timeZoneId = timeZoneId
        self.dayKey = dayKey
        self.countryCode = countryCode
        self.countryName = countryName
    }

    var source: LocationSampleSource {
        get { LocationSampleSource(rawValue: sourceRaw) ?? .app }
        set { sourceRaw = newValue.rawValue }
    }
}
