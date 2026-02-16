//
//  PhotoSignal.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import SwiftData

@Model
final class PhotoSignal {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    @Attribute(.unique) var assetIdHash: String
    var timeZoneId: String?
    var dayKey: String
    var countryCode: String?
    var countryName: String?

    init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        assetIdHash: String,
        timeZoneId: String?,
        dayKey: String,
        countryCode: String?,
        countryName: String?
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.assetIdHash = assetIdHash
        self.timeZoneId = timeZoneId
        self.dayKey = dayKey
        self.countryCode = countryCode
        self.countryName = countryName
    }
}
