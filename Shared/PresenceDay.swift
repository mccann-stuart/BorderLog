//
//  PresenceDay.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import SwiftData

@Model
final class PresenceDay {
    @Attribute(.unique) var dayKey: String
    var date: Date
    var timeZoneId: String?
    var countryCode: String?
    var countryName: String?
    var confidence: Double
    var confidenceLabelRaw: String
    var sourcesRaw: Int
    var isOverride: Bool
    var stayCount: Int
    var photoCount: Int
    var locationCount: Int
    var calendarCount: Int = 0
    var isDisputed: Bool = false
    var suggestedCountryCode1: String?
    var suggestedCountryName1: String?
    var suggestedCountryCode2: String?
    var suggestedCountryName2: String?

    init(
        dayKey: String,
        date: Date,
        timeZoneId: String?,
        countryCode: String?,
        countryName: String?,
        confidence: Double,
        confidenceLabel: ConfidenceLabel,
        sources: SignalSourceMask,
        isOverride: Bool,
        stayCount: Int,
        photoCount: Int,
        locationCount: Int,
        calendarCount: Int = 0,
        isDisputed: Bool = false,
        suggestedCountryCode1: String? = nil,
        suggestedCountryName1: String? = nil,
        suggestedCountryCode2: String? = nil,
        suggestedCountryName2: String? = nil
    ) {
        self.dayKey = dayKey
        self.date = date
        self.timeZoneId = timeZoneId
        self.countryCode = countryCode
        self.countryName = countryName
        self.confidence = confidence
        self.confidenceLabelRaw = confidenceLabel.rawValue
        self.sourcesRaw = sources.rawValue
        self.isOverride = isOverride
        self.stayCount = stayCount
        self.photoCount = photoCount
        self.locationCount = locationCount
        self.calendarCount = calendarCount
        self.isDisputed = isDisputed
        self.suggestedCountryCode1 = suggestedCountryCode1
        self.suggestedCountryName1 = suggestedCountryName1
        self.suggestedCountryCode2 = suggestedCountryCode2
        self.suggestedCountryName2 = suggestedCountryName2
    }

    var confidenceLabel: ConfidenceLabel {
        get { ConfidenceLabel(rawValue: confidenceLabelRaw) ?? .low }
        set { confidenceLabelRaw = newValue.rawValue }
    }

    var sources: SignalSourceMask {
        get { SignalSourceMask(rawValue: sourcesRaw) }
        set { sourcesRaw = newValue.rawValue }
    }
}
