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
    var countryAllocations: [PresenceCountryAllocation] = []
    var zoneOverlays: [String] = []
    var evidenceEntries: [PresenceEvidenceEntry] = []
    var confidence: Double
    var confidenceLabelRaw: String
    var sourcesRaw: Int
    var isOverride: Bool
    var stayCount: Int
    var photoCount: Int
    var locationCount: Int
    var calendarCount: Int = 0
    var isDisputed: Bool = false
    var confidenceScore: Double = 0
    var confidenceRunnerUpScore: Double = 0
    var confidenceMargin: Double = 0
    var confidenceCalibrationSummary: String = ""
    var suggestedCountryCode1: String?
    var suggestedCountryName1: String?
    var suggestedCountryCode2: String?
    var suggestedCountryName2: String?

    init(
        dayKey: String,
        date: Date,
        timeZoneId: String?,
        countryAllocations: [PresenceCountryAllocation],
        zoneOverlays: [String],
        evidenceEntries: [PresenceEvidenceEntry],
        confidenceBreakdown: PresenceConfidenceBreakdown,
        sourceSummary: SignalSourceMask,
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
        self.countryAllocations = countryAllocations
        self.zoneOverlays = zoneOverlays
        self.evidenceEntries = evidenceEntries
        self.confidence = confidenceBreakdown.normalizedWinningShare
        self.confidenceLabelRaw = confidenceBreakdown.label.rawValue
        self.sourcesRaw = sourceSummary.rawValue
        self.isOverride = isOverride
        self.stayCount = stayCount
        self.photoCount = photoCount
        self.locationCount = locationCount
        self.calendarCount = calendarCount
        self.isDisputed = isDisputed
        self.confidenceScore = confidenceBreakdown.score
        self.confidenceRunnerUpScore = confidenceBreakdown.runnerUpScore
        self.confidenceMargin = confidenceBreakdown.margin
        self.confidenceCalibrationSummary = confidenceBreakdown.calibrationSummary
        self.suggestedCountryCode1 = suggestedCountryCode1
        self.suggestedCountryName1 = suggestedCountryName1
        self.suggestedCountryCode2 = suggestedCountryCode2
        self.suggestedCountryName2 = suggestedCountryName2
    }

    convenience init(
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
        let allocations: [PresenceCountryAllocation]
        if let countryName {
            allocations = [PresenceCountryAllocation(countryCode: countryCode, countryName: countryName, normalizedShare: 1.0)]
        } else {
            allocations = []
        }

        self.init(
            dayKey: dayKey,
            date: date,
            timeZoneId: timeZoneId,
            countryAllocations: allocations,
            zoneOverlays: [],
            evidenceEntries: [],
            confidenceBreakdown: PresenceConfidenceBreakdown(
                score: confidence,
                runnerUpScore: 0,
                margin: confidence,
                normalizedWinningShare: confidence,
                label: confidenceLabel,
                calibrationSummary: "legacy"
            ),
            sourceSummary: sources,
            isOverride: isOverride,
            stayCount: stayCount,
            photoCount: photoCount,
            locationCount: locationCount,
            calendarCount: calendarCount,
            isDisputed: isDisputed,
            suggestedCountryCode1: suggestedCountryCode1,
            suggestedCountryName1: suggestedCountryName1,
            suggestedCountryCode2: suggestedCountryCode2,
            suggestedCountryName2: suggestedCountryName2
        )
    }

    convenience init(
        dayKey: String,
        date: Date,
        timeZoneId: String?,
        contributedCountries: [ContributedCountry],
        zoneOverlays: [String],
        evidence: [SignalImpact],
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
        self.init(
            dayKey: dayKey,
            date: date,
            timeZoneId: timeZoneId,
            countryAllocations: contributedCountries,
            zoneOverlays: zoneOverlays,
            evidenceEntries: evidence,
            confidenceBreakdown: PresenceConfidenceBreakdown(
                score: confidence,
                runnerUpScore: 0,
                margin: confidence,
                normalizedWinningShare: confidence,
                label: confidenceLabel,
                calibrationSummary: "legacy"
            ),
            sourceSummary: sources,
            isOverride: isOverride,
            stayCount: stayCount,
            photoCount: photoCount,
            locationCount: locationCount,
            calendarCount: calendarCount,
            isDisputed: isDisputed,
            suggestedCountryCode1: suggestedCountryCode1,
            suggestedCountryName1: suggestedCountryName1,
            suggestedCountryCode2: suggestedCountryCode2,
            suggestedCountryName2: suggestedCountryName2
        )
    }

    var confidenceLabel: ConfidenceLabel {
        get { ConfidenceLabel(rawValue: confidenceLabelRaw) ?? .low }
        set { confidenceLabelRaw = newValue.rawValue }
    }

    var sources: SignalSourceMask {
        get { SignalSourceMask(rawValue: sourcesRaw) }
        set { sourcesRaw = newValue.rawValue }
    }

    var confidenceBreakdown: PresenceConfidenceBreakdown {
        get {
            PresenceConfidenceBreakdown(
                score: confidenceScore,
                runnerUpScore: confidenceRunnerUpScore,
                margin: confidenceMargin,
                normalizedWinningShare: confidence,
                label: confidenceLabel,
                calibrationSummary: confidenceCalibrationSummary
            )
        }
        set {
            confidence = newValue.normalizedWinningShare
            confidenceLabel = newValue.label
            confidenceScore = newValue.score
            confidenceRunnerUpScore = newValue.runnerUpScore
            confidenceMargin = newValue.margin
            confidenceCalibrationSummary = newValue.calibrationSummary
        }
    }

    var sourceSummary: SignalSourceMask {
        get { sources }
        set { sources = newValue }
    }

    var contributedCountries: [ContributedCountry] {
        get { countryAllocations }
        set { countryAllocations = newValue }
    }

    var evidence: [SignalImpact] {
        get { evidenceEntries }
        set { evidenceEntries = newValue }
    }

    var countryCode: String? {
        countryAllocations.first?.countryCode
    }

    var countryName: String? {
        countryAllocations.first?.countryName
    }

    var isManuallyModified: Bool {
        isOverride || stayCount > 0
    }
}
