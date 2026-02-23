//
//  CalendarSignal.swift
//  Learn
//
//  Created by Mccann Stuart on 17/02/2026.
//

import Foundation
import SwiftData

@Model
final class CalendarSignal {
    var timestamp: Date
    var dayKey: String
    var latitude: Double
    var longitude: Double
    var countryCode: String?
    var countryName: String?
    var timeZoneId: String?
    @Attribute(.unique) var eventIdentifier: String
    var title: String?
    var source: String?

    init(
        timestamp: Date,
        dayKey: String,
        latitude: Double,
        longitude: Double,
        countryCode: String?,
        countryName: String?,
        timeZoneId: String?,
        eventIdentifier: String,
        title: String?,
        source: String?
    ) {
        self.timestamp = timestamp
        self.dayKey = dayKey
        self.latitude = latitude
        self.longitude = longitude
        self.countryCode = countryCode
        self.countryName = countryName
        self.timeZoneId = timeZoneId
        self.eventIdentifier = eventIdentifier
        self.title = title
        self.source = source
    }
}
