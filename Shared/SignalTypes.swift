//
//  SignalTypes.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation

nonisolated enum ConfidenceLabel: String, CaseIterable, Codable, Sendable {
    case high
    case medium
    case low
}

nonisolated enum PresenceEvidencePhase: String, Codable, CaseIterable, Sendable {
    case base
    case contextual
    case override
    case normalization
}

nonisolated struct PresenceCountryAllocation: Codable, Sendable, Equatable {
    let countryCode: String?
    let countryName: String
    let normalizedShare: Double

    init(countryCode: String?, countryName: String, normalizedShare: Double) {
        self.countryCode = countryCode
        self.countryName = countryName
        self.normalizedShare = normalizedShare
    }

    init(countryCode: String?, countryName: String, probability: Double) {
        self.init(countryCode: countryCode, countryName: countryName, normalizedShare: probability)
    }

    var probability: Double {
        normalizedShare
    }
}

typealias ContributedCountry = PresenceCountryAllocation

nonisolated struct PresenceEvidenceEntry: Codable, Sendable, Equatable {
    let dayKey: String
    let processorID: String
    let countryCode: String?
    let countryName: String
    let rawWeight: Double
    let calibratedWeight: Double
    let phase: PresenceEvidencePhase
    let reason: String
    var contributedToFinalResult: Bool
    let timeZoneId: String?

    init(
        dayKey: String,
        processorID: String,
        countryCode: String?,
        countryName: String,
        rawWeight: Double,
        calibratedWeight: Double,
        phase: PresenceEvidencePhase,
        reason: String,
        contributedToFinalResult: Bool = false,
        timeZoneId: String? = nil
    ) {
        self.dayKey = dayKey
        self.processorID = processorID
        self.countryCode = countryCode
        self.countryName = countryName
        self.rawWeight = rawWeight
        self.calibratedWeight = calibratedWeight
        self.phase = phase
        self.reason = reason
        self.contributedToFinalResult = contributedToFinalResult
        self.timeZoneId = timeZoneId
    }

    init(
        source: String,
        countryCode: String?,
        countryName: String,
        scoreDelta: Double
    ) {
        self.init(
            dayKey: "",
            processorID: source,
            countryCode: countryCode,
            countryName: countryName,
            rawWeight: scoreDelta,
            calibratedWeight: scoreDelta,
            phase: .base,
            reason: source,
            contributedToFinalResult: false,
            timeZoneId: nil
        )
    }

    var source: String {
        processorID
    }

    var scoreDelta: Double {
        calibratedWeight
    }
}

typealias SignalImpact = PresenceEvidenceEntry

nonisolated struct PresenceConfidenceBreakdown: Codable, Sendable, Equatable {
    let score: Double
    let runnerUpScore: Double
    let margin: Double
    let normalizedWinningShare: Double
    let label: ConfidenceLabel
    let calibrationSummary: String

    nonisolated init(
        score: Double,
        runnerUpScore: Double,
        margin: Double,
        normalizedWinningShare: Double,
        label: ConfidenceLabel,
        calibrationSummary: String
    ) {
        self.score = score
        self.runnerUpScore = runnerUpScore
        self.margin = margin
        self.normalizedWinningShare = normalizedWinningShare
        self.label = label
        self.calibrationSummary = calibrationSummary
    }
}

nonisolated struct SignalSourceMask: OptionSet, Codable, Sendable {
    let rawValue: Int

    nonisolated static let override = SignalSourceMask(rawValue: 1 << 0)
    nonisolated static let stay = SignalSourceMask(rawValue: 1 << 1)
    nonisolated static let photo = SignalSourceMask(rawValue: 1 << 2)
    nonisolated static let location = SignalSourceMask(rawValue: 1 << 3)
    nonisolated static let calendar = SignalSourceMask(rawValue: 1 << 4)

    nonisolated static let none: SignalSourceMask = []
    nonisolated static let all: SignalSourceMask = [.`override`, .stay, .photo, .location, .calendar]

    nonisolated static func from(processorIDs: some Sequence<String>) -> SignalSourceMask {
        processorIDs.reduce(into: .none) { partialResult, processorID in
            let normalized = processorID.lowercased()
            if normalized.contains("override") {
                partialResult.formUnion(.override)
            } else if normalized.contains("stay") {
                partialResult.formUnion(.stay)
            } else if normalized.contains("photo") {
                partialResult.formUnion(.photo)
            } else if normalized.contains("location") {
                partialResult.formUnion(.location)
            } else if normalized.contains("calendar") {
                partialResult.formUnion(.calendar)
            }
        }
    }
}

nonisolated struct CalendarSignalInfo: Sendable {
    let dayKey: String
    let countryCode: String?
    let countryName: String
    let timeZoneId: String?
    let bucketingTimeZoneId: String?
    let eventIdentifier: String?
    let source: String?

    nonisolated init(
        dayKey: String,
        countryCode: String?,
        countryName: String,
        timeZoneId: String?,
        bucketingTimeZoneId: String?,
        eventIdentifier: String? = nil,
        source: String? = nil
    ) {
        self.dayKey = dayKey
        self.countryCode = countryCode
        self.countryName = countryName
        self.timeZoneId = timeZoneId
        self.bucketingTimeZoneId = bucketingTimeZoneId
        self.eventIdentifier = eventIdentifier
        self.source = source
    }
}

nonisolated struct LocationSignalInfo: Sendable {
    let dayKey: String
    let countryCode: String?
    let countryName: String
    let accuracyMeters: Double
    let timeZoneId: String?
}

nonisolated struct PhotoSignalInfo: Sendable {
    let dayKey: String
    let countryCode: String?
    let countryName: String
    let timeZoneId: String?
}

nonisolated struct StayPresenceInfo: Sendable {
    let entryDayKey: String
    let exitDayKey: String?
    let dayTimeZoneId: String
    let countryCode: String?
    let countryName: String
}

nonisolated struct OverridePresenceInfo: Sendable {
    let dayKey: String
    let dayTimeZoneId: String
    let countryCode: String?
    let countryName: String
}

nonisolated struct PresenceDayResult: Sendable {
    let dayKey: String
    let date: Date
    let timeZoneId: String?
    let countryAllocations: [PresenceCountryAllocation]
    let zoneOverlays: [String]
    let evidenceEntries: [PresenceEvidenceEntry]
    let confidenceBreakdown: PresenceConfidenceBreakdown
    let sourceSummary: SignalSourceMask
    let isOverride: Bool
    let isDisputed: Bool
    let stayCount: Int
    let photoCount: Int
    let locationCount: Int
    let calendarCount: Int
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
        isDisputed: Bool,
        stayCount: Int,
        photoCount: Int,
        locationCount: Int,
        calendarCount: Int,
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
        self.confidenceBreakdown = confidenceBreakdown
        self.sourceSummary = sourceSummary
        self.isOverride = isOverride
        self.isDisputed = isDisputed
        self.stayCount = stayCount
        self.photoCount = photoCount
        self.locationCount = locationCount
        self.calendarCount = calendarCount
        self.suggestedCountryCode1 = suggestedCountryCode1
        self.suggestedCountryName1 = suggestedCountryName1
        self.suggestedCountryCode2 = suggestedCountryCode2
        self.suggestedCountryName2 = suggestedCountryName2
    }

    init(
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
        isDisputed: Bool,
        stayCount: Int,
        photoCount: Int,
        locationCount: Int,
        calendarCount: Int,
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
            isDisputed: isDisputed,
            stayCount: stayCount,
            photoCount: photoCount,
            locationCount: locationCount,
            calendarCount: calendarCount,
            suggestedCountryCode1: suggestedCountryCode1,
            suggestedCountryName1: suggestedCountryName1,
            suggestedCountryCode2: suggestedCountryCode2,
            suggestedCountryName2: suggestedCountryName2
        )
    }

    nonisolated var contributedCountries: [ContributedCountry] {
        countryAllocations
    }

    nonisolated var evidence: [SignalImpact] {
        evidenceEntries
    }

    nonisolated var confidence: Double {
        confidenceBreakdown.normalizedWinningShare
    }

    nonisolated var confidenceLabel: ConfidenceLabel {
        confidenceBreakdown.label
    }

    nonisolated var sources: SignalSourceMask {
        sourceSummary
    }

    nonisolated var countryCode: String? {
        countryAllocations.first?.countryCode
    }

    nonisolated var countryName: String? {
        countryAllocations.first?.countryName
    }
}
