//
//  PresenceDay.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import SwiftData

@Model
nonisolated final class PresenceDay {
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
        locationCount: Int
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
