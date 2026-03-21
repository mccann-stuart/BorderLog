//
//  DebugDataStoreExportService.swift
//  Learn
//
//  Created by Codex on 21/03/2026.
//

import Foundation
@preconcurrency import SwiftData

struct DebugExportAppVariantFlags: Codable, Sendable {
    let cloudKitFeatureEnabled: Bool
    let appleSignInEnabled: Bool
    let appGroupAvailable: Bool
}

struct DebugExportMetadata: Codable, Sendable {
    let exportedAt: Date
    let appVersion: String
    let appBuild: String
    let bundleIdentifier: String?
    let deviceModelCategory: String
    let operatingSystemVersion: String
    let localeIdentifier: String
    let currentTimeZoneId: String
    let appVariantFlags: DebugExportAppVariantFlags
}

struct DebugExportPermissionStatus: Codable, Sendable {
    let rawValue: Int
    let label: String
}

struct DebugExportAppState: Codable, Sendable {
    let hasCompletedOnboarding: Bool
    let didBootstrapInference: Bool
    let hasPromptedLocation: Bool
    let hasPromptedPhotos: Bool
    let hasPromptedCalendar: Bool
    let usePolygonMapView: Bool
    let showSchengenDashboardSection: Bool
    let cloudKitSyncEnabled: Bool
    let requireBiometrics: Bool
    let locationPermission: DebugExportPermissionStatus
    let photoPermission: DebugExportPermissionStatus
    let calendarPermission: DebugExportPermissionStatus
    let dataStoreMode: String
    let appGroupAvailable: Bool
    let cloudKitFeatureEnabled: Bool
    let currentStoreEpoch: Int
    let storedStoreEpoch: Int
    let widgetLastWriteDate: Date?
    let pendingWidgetSnapshotCount: Int
}

struct DebugExportUserData: Codable, Sendable {
    let passportNationality: String?
    let homeCountry: String?
    let appleUserId: String?
    let appleSignInEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case passportNationality
        case homeCountry
        case appleUserId
        case appleSignInEnabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(passportNationality, forKey: .passportNationality)
        try container.encode(homeCountry, forKey: .homeCountry)
        try container.encode(appleUserId, forKey: .appleUserId)
        try container.encode(appleSignInEnabled, forKey: .appleSignInEnabled)
    }
}

struct DebugExportDateRange: Codable, Sendable {
    let earliest: Date
    let latest: Date
}

struct DebugExportRecordCounts: Codable, Sendable {
    let stays: Int
    let dayOverrides: Int
    let locationSamples: Int
    let photoSignals: Int
    let calendarSignals: Int
    let presenceDays: Int
    let countryConfigs: Int
    let photoIngestStates: Int
    let pendingLocationSnapshots: Int
}

struct DebugExportDateBounds: Codable, Sendable {
    let stays: DebugExportDateRange?
    let dayOverrides: DebugExportDateRange?
    let locationSamples: DebugExportDateRange?
    let photoSignals: DebugExportDateRange?
    let calendarSignals: DebugExportDateRange?
    let presenceDays: DebugExportDateRange?
    let photoIngestActivity: DebugExportDateRange?
}

struct DebugExportPresenceDayTotals: Codable, Sendable {
    let unknown: Int
    let disputed: Int
    let manual: Int
}

struct DebugExportSourceTotals: Codable, Sendable {
    let stayRecords: Int
    let overrideRecords: Int
    let locationSampleRecords: Int
    let photoSignalRecords: Int
    let calendarSignalRecords: Int
    let appLocationSamples: Int
    let widgetLocationSamples: Int
    let presenceDaysWithOverrideSource: Int
    let presenceDaysWithStaySource: Int
    let presenceDaysWithPhotoSource: Int
    let presenceDaysWithLocationSource: Int
    let presenceDaysWithCalendarSource: Int
}

struct DebugExportSchengenLedgerSummary: Codable, Sendable {
    let usedDays: Int
    let remainingDays: Int
    let overstayDays: Int
    let unknownDays: Int
    let windowStart: Date
    let windowEnd: Date
}

struct DebugExportSummary: Codable, Sendable {
    let recordCounts: DebugExportRecordCounts
    let dateBounds: DebugExportDateBounds
    let presenceDayTotals: DebugExportPresenceDayTotals
    let sourceTotals: DebugExportSourceTotals
    let schengenLedgerSummary: DebugExportSchengenLedgerSummary
}

struct DebugExportStayRecord: Codable, Sendable {
    let countryName: String
    let countryCode: String?
    let dayTimeZoneId: String
    let entryDayKey: String
    let exitDayKey: String?
    let regionRaw: String
    let enteredOn: Date
    let exitedOn: Date?
    let notes: String
    let isOngoing: Bool
    let durationDaysAtExport: Int
}

struct DebugExportDayOverrideRecord: Codable, Sendable {
    let dayKey: String
    let dayTimeZoneId: String
    let date: Date
    let countryName: String
    let countryCode: String?
    let regionRaw: String
    let notes: String
}

struct DebugExportLocationSampleRecord: Codable, Sendable {
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double
    let sourceRaw: String
    let dayKey: String
    let timeZoneId: String?
    let countryCode: String?
    let countryName: String?
}

struct DebugExportPhotoSignalRecord: Codable, Sendable {
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let assetIdHash: String
    let dayKey: String
    let timeZoneId: String?
    let countryCode: String?
    let countryName: String?
}

struct DebugExportCalendarSignalRecord: Codable, Sendable {
    let timestamp: Date
    let dayKey: String
    let latitude: Double
    let longitude: Double
    let countryCode: String?
    let countryName: String?
    let timeZoneId: String?
    let bucketingTimeZoneId: String?
    let eventIdentifier: String
    let title: String?
    let source: String?
}

struct DebugExportPresenceDayRecord: Codable, Sendable {
    let dayKey: String
    let date: Date
    let timeZoneId: String?
    let countryCode: String?
    let countryName: String?
    let contributedCountries: [ContributedCountry]
    let zoneOverlays: [String]
    let evidence: [SignalImpact]
    let confidence: Double
    let confidenceLabelRaw: String
    let sourcesRaw: Int
    let sourceLabels: [String]
    let isOverride: Bool
    let stayCount: Int
    let photoCount: Int
    let locationCount: Int
    let calendarCount: Int
    let isDisputed: Bool
    let isManuallyModified: Bool
    let suggestedCountryCode1: String?
    let suggestedCountryName1: String?
    let suggestedCountryCode2: String?
    let suggestedCountryName2: String?
}

struct DebugExportCountryConfigRecord: Codable, Sendable {
    let countryCode: String
    let maxAllowedDays: Int?
}

struct DebugExportPhotoIngestStateRecord: Codable, Sendable {
    let lastIngestedAt: Date?
    let lastAssetCreationDate: Date?
    let lastAssetIdHash: String?
    let fullScanCompleted: Bool
    let lastFullScanAt: Date?
}

struct DebugExportPendingLocationSnapshot: Codable, Sendable {
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double
    let sourceRaw: String
    let timeZoneId: String?
    let dayKey: String
    let countryCode: String?
    let countryName: String?
}

struct DebugExportRecords: Codable, Sendable {
    let stays: [DebugExportStayRecord]
    let dayOverrides: [DebugExportDayOverrideRecord]
    let locationSamples: [DebugExportLocationSampleRecord]
    let photoSignals: [DebugExportPhotoSignalRecord]
    let calendarSignals: [DebugExportCalendarSignalRecord]
    let presenceDays: [DebugExportPresenceDayRecord]
    let countryConfigs: [DebugExportCountryConfigRecord]
    let photoIngestStates: [DebugExportPhotoIngestStateRecord]
    let pendingLocationSnapshots: [DebugExportPendingLocationSnapshot]
}

struct DebugExportDaySourceCounts: Codable, Sendable {
    let stays: Int
    let overrides: Int
    let locations: Int
    let photos: Int
    let calendarSignals: Int
}

struct DebugExportPresenceSummary: Codable, Sendable {
    let countryCode: String?
    let countryName: String?
    let suggestedCountryCode1: String?
    let suggestedCountryName1: String?
    let suggestedCountryCode2: String?
    let suggestedCountryName2: String?
    let contributedCountries: [ContributedCountry]
    let sourceLabels: [String]
    let confidence: Double
    let confidenceLabelRaw: String
    let isDisputed: Bool
    let isManuallyModified: Bool
}

struct DebugExportDaySnapshot: Codable, Sendable {
    let dayKey: String
    let date: Date
    let timeZoneId: String?
    let presence: DebugExportPresenceDayRecord?
    let presenceSummary: DebugExportPresenceSummary?
    let dayOverride: DebugExportDayOverrideRecord?
    let staysCoveringDay: [DebugExportStayRecord]
    let locations: [DebugExportLocationSampleRecord]
    let photos: [DebugExportPhotoSignalRecord]
    let calendarSignals: [DebugExportCalendarSignalRecord]
    let sourceCounts: DebugExportDaySourceCounts
    let hasAnyRawEvidence: Bool

    enum CodingKeys: String, CodingKey {
        case dayKey
        case date
        case timeZoneId
        case presence
        case presenceSummary
        case dayOverride = "override"
        case staysCoveringDay
        case locations
        case photos
        case calendarSignals
        case sourceCounts
        case hasAnyRawEvidence
    }
}

struct DebugDataStoreExportPayload: Codable, Sendable {
    let metadata: DebugExportMetadata
    let appState: DebugExportAppState
    let userData: DebugExportUserData
    let summary: DebugExportSummary
    let records: DebugExportRecords
    let days: [DebugExportDaySnapshot]
}

struct DebugExportRuntimeContext: Codable, Sendable {
    let metadata: DebugExportMetadata
    let appState: DebugExportAppState
    let userData: DebugExportUserData
    let pendingLocationSnapshots: [DebugExportPendingLocationSnapshot]
}

@ModelActor
actor DebugDataStoreExportService {
    func buildPayload(context: DebugExportRuntimeContext) throws -> DebugDataStoreExportPayload {
        let stays = try modelContext.fetch(FetchDescriptor<Stay>())
        let overrides = try modelContext.fetch(FetchDescriptor<DayOverride>())
        let locationSamples = try modelContext.fetch(FetchDescriptor<LocationSample>())
        let photoSignals = try modelContext.fetch(FetchDescriptor<PhotoSignal>())
        let calendarSignals = try modelContext.fetch(FetchDescriptor<CalendarSignal>())
        let presenceDays = try modelContext.fetch(FetchDescriptor<PresenceDay>())
        let countryConfigs = try modelContext.fetch(FetchDescriptor<CountryConfig>())
        let photoIngestStates = try modelContext.fetch(FetchDescriptor<PhotoIngestState>())

        let exportedAt = context.metadata.exportedAt

        let stayRecords = stays
            .map { stay in
                DebugExportStayRecord(
                    countryName: stay.countryName,
                    countryCode: stay.countryCode,
                    dayTimeZoneId: stay.dayTimeZoneId,
                    entryDayKey: stay.entryDayKey,
                    exitDayKey: stay.exitDayKey,
                    regionRaw: stay.regionRaw,
                    enteredOn: stay.enteredOn,
                    exitedOn: stay.exitedOn,
                    notes: stay.notes,
                    isOngoing: stay.isOngoing,
                    durationDaysAtExport: stay.durationInDays(asOf: exportedAt)
                )
            }
            .sorted {
                ($0.entryDayKey, $0.countryName, $0.enteredOn) < ($1.entryDayKey, $1.countryName, $1.enteredOn)
            }

        let overrideRecords = overrides
            .map { override in
                DebugExportDayOverrideRecord(
                    dayKey: override.dayKey,
                    dayTimeZoneId: override.dayTimeZoneId,
                    date: override.date,
                    countryName: override.countryName,
                    countryCode: override.countryCode,
                    regionRaw: override.regionRaw,
                    notes: override.notes
                )
            }
            .sorted {
                ($0.dayKey, $0.countryName) < ($1.dayKey, $1.countryName)
            }

        let locationRecords = locationSamples
            .map { sample in
                DebugExportLocationSampleRecord(
                    timestamp: sample.timestamp,
                    latitude: sample.latitude,
                    longitude: sample.longitude,
                    accuracyMeters: sample.accuracyMeters,
                    sourceRaw: sample.sourceRaw,
                    dayKey: sample.dayKey,
                    timeZoneId: sample.timeZoneId,
                    countryCode: sample.countryCode,
                    countryName: sample.countryName
                )
            }
            .sorted {
                ($0.dayKey, $0.timestamp, $0.sourceRaw, $0.countryName ?? "") < ($1.dayKey, $1.timestamp, $1.sourceRaw, $1.countryName ?? "")
            }

        let photoRecords = photoSignals
            .map { signal in
                DebugExportPhotoSignalRecord(
                    timestamp: signal.timestamp,
                    latitude: signal.latitude,
                    longitude: signal.longitude,
                    assetIdHash: signal.assetIdHash,
                    dayKey: signal.dayKey,
                    timeZoneId: signal.timeZoneId,
                    countryCode: signal.countryCode,
                    countryName: signal.countryName
                )
            }
            .sorted {
                ($0.dayKey, $0.timestamp, $0.assetIdHash) < ($1.dayKey, $1.timestamp, $1.assetIdHash)
            }

        let calendarRecords = calendarSignals
            .map { signal in
                DebugExportCalendarSignalRecord(
                    timestamp: signal.timestamp,
                    dayKey: signal.dayKey,
                    latitude: signal.latitude,
                    longitude: signal.longitude,
                    countryCode: signal.countryCode,
                    countryName: signal.countryName,
                    timeZoneId: signal.timeZoneId,
                    bucketingTimeZoneId: signal.bucketingTimeZoneId,
                    eventIdentifier: signal.eventIdentifier,
                    title: signal.title,
                    source: signal.source
                )
            }
            .sorted {
                ($0.dayKey, $0.timestamp, $0.eventIdentifier) < ($1.dayKey, $1.timestamp, $1.eventIdentifier)
            }

        let presenceRecords = presenceDays
            .map { day in
                let sourceMask = day.sources
                return DebugExportPresenceDayRecord(
                    dayKey: day.dayKey,
                    date: day.date,
                    timeZoneId: day.timeZoneId,
                    countryCode: day.countryCode,
                    countryName: day.countryName,
                    contributedCountries: day.contributedCountries,
                    zoneOverlays: day.zoneOverlays,
                    evidence: day.evidence,
                    confidence: day.confidence,
                    confidenceLabelRaw: day.confidenceLabelRaw,
                    sourcesRaw: day.sourcesRaw,
                    sourceLabels: Self.sourceLabels(for: sourceMask),
                    isOverride: day.isOverride,
                    stayCount: day.stayCount,
                    photoCount: day.photoCount,
                    locationCount: day.locationCount,
                    calendarCount: day.calendarCount,
                    isDisputed: day.isDisputed,
                    isManuallyModified: day.isManuallyModified,
                    suggestedCountryCode1: day.suggestedCountryCode1,
                    suggestedCountryName1: day.suggestedCountryName1,
                    suggestedCountryCode2: day.suggestedCountryCode2,
                    suggestedCountryName2: day.suggestedCountryName2
                )
            }
            .sorted {
                ($0.dayKey, $0.countryName ?? "") < ($1.dayKey, $1.countryName ?? "")
            }

        let countryConfigRecords = countryConfigs
            .map { config in
                DebugExportCountryConfigRecord(countryCode: config.countryCode, maxAllowedDays: config.maxAllowedDays)
            }
            .sorted { $0.countryCode < $1.countryCode }

        let photoIngestStateRecords = photoIngestStates
            .map { state in
                DebugExportPhotoIngestStateRecord(
                    lastIngestedAt: state.lastIngestedAt,
                    lastAssetCreationDate: state.lastAssetCreationDate,
                    lastAssetIdHash: state.lastAssetIdHash,
                    fullScanCompleted: state.fullScanCompleted,
                    lastFullScanAt: state.lastFullScanAt
                )
            }
            .sorted {
                ($0.lastIngestedAt ?? .distantPast, $0.lastFullScanAt ?? .distantPast, $0.lastAssetIdHash ?? "") <
                ($1.lastIngestedAt ?? .distantPast, $1.lastFullScanAt ?? .distantPast, $1.lastAssetIdHash ?? "")
            }

        let pendingLocationSnapshots = context.pendingLocationSnapshots.sorted {
            ($0.dayKey, $0.timestamp, $0.sourceRaw) < ($1.dayKey, $1.timestamp, $1.sourceRaw)
        }

        let records = DebugExportRecords(
            stays: stayRecords,
            dayOverrides: overrideRecords,
            locationSamples: locationRecords,
            photoSignals: photoRecords,
            calendarSignals: calendarRecords,
            presenceDays: presenceRecords,
            countryConfigs: countryConfigRecords,
            photoIngestStates: photoIngestStateRecords,
            pendingLocationSnapshots: pendingLocationSnapshots
        )

        let schengenSummary = SchengenLedgerCalculator.summary(for: presenceDays, asOf: exportedAt)
        let summary = Self.makeSummary(
            records: records,
            schengenLedgerSummary: DebugExportSchengenLedgerSummary(
                usedDays: schengenSummary.usedDays,
                remainingDays: schengenSummary.remainingDays,
                overstayDays: schengenSummary.overstayDays,
                unknownDays: schengenSummary.unknownDays,
                windowStart: schengenSummary.windowStart,
                windowEnd: schengenSummary.windowEnd
            )
        )
        let days = Self.makeDaySnapshots(records: records, exportedAt: exportedAt)

        return DebugDataStoreExportPayload(
            metadata: context.metadata,
            appState: context.appState,
            userData: context.userData,
            summary: summary,
            records: records,
            days: days
        )
    }

    func exportJSON(context: DebugExportRuntimeContext) throws -> Data {
        let payload = try buildPayload(context: context)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.iso8601String(from: date))
        }
        return try encoder.encode(payload)
    }

    private static func makeSummary(
        records: DebugExportRecords,
        schengenLedgerSummary: DebugExportSchengenLedgerSummary
    ) -> DebugExportSummary {
        let recordCounts = DebugExportRecordCounts(
            stays: records.stays.count,
            dayOverrides: records.dayOverrides.count,
            locationSamples: records.locationSamples.count,
            photoSignals: records.photoSignals.count,
            calendarSignals: records.calendarSignals.count,
            presenceDays: records.presenceDays.count,
            countryConfigs: records.countryConfigs.count,
            photoIngestStates: records.photoIngestStates.count,
            pendingLocationSnapshots: records.pendingLocationSnapshots.count
        )

        let dateBounds = DebugExportDateBounds(
            stays: dateRange(for: records.stays, at: \.enteredOn),
            dayOverrides: dateRange(for: records.dayOverrides, at: \.date),
            locationSamples: dateRange(for: records.locationSamples, at: \.timestamp),
            photoSignals: dateRange(for: records.photoSignals, at: \.timestamp),
            calendarSignals: dateRange(for: records.calendarSignals, at: \.timestamp),
            presenceDays: dateRange(for: records.presenceDays, at: \.date),
            photoIngestActivity: dateRange(for: records.photoIngestStates) { state in
                [state.lastIngestedAt, state.lastAssetCreationDate, state.lastFullScanAt].compactMap { $0 }
            }
        )

        let presenceDayTotals = DebugExportPresenceDayTotals(
            unknown: records.presenceDays.filter { $0.countryCode == nil && $0.countryName == nil }.count,
            disputed: records.presenceDays.filter(\.isDisputed).count,
            manual: records.presenceDays.filter(\.isManuallyModified).count
        )

        let sourceTotals = DebugExportSourceTotals(
            stayRecords: records.stays.count,
            overrideRecords: records.dayOverrides.count,
            locationSampleRecords: records.locationSamples.count,
            photoSignalRecords: records.photoSignals.count,
            calendarSignalRecords: records.calendarSignals.count,
            appLocationSamples: records.locationSamples.filter { $0.sourceRaw == LocationSampleSource.app.rawValue }.count,
            widgetLocationSamples: records.locationSamples.filter { $0.sourceRaw == LocationSampleSource.widget.rawValue }.count,
            presenceDaysWithOverrideSource: records.presenceDays.filter { $0.sourceLabels.contains("override") }.count,
            presenceDaysWithStaySource: records.presenceDays.filter { $0.sourceLabels.contains("stay") }.count,
            presenceDaysWithPhotoSource: records.presenceDays.filter { $0.sourceLabels.contains("photo") }.count,
            presenceDaysWithLocationSource: records.presenceDays.filter { $0.sourceLabels.contains("location") }.count,
            presenceDaysWithCalendarSource: records.presenceDays.filter { $0.sourceLabels.contains("calendar") }.count
        )

        return DebugExportSummary(
            recordCounts: recordCounts,
            dateBounds: dateBounds,
            presenceDayTotals: presenceDayTotals,
            sourceTotals: sourceTotals,
            schengenLedgerSummary: schengenLedgerSummary
        )
    }

    private static func makeDaySnapshots(
        records: DebugExportRecords,
        exportedAt: Date
    ) -> [DebugExportDaySnapshot] {
        var allDayKeys = Set(records.presenceDays.map(\.dayKey))
        allDayKeys.formUnion(records.dayOverrides.map(\.dayKey))
        allDayKeys.formUnion(records.locationSamples.map(\.dayKey))
        allDayKeys.formUnion(records.photoSignals.map(\.dayKey))
        allDayKeys.formUnion(records.calendarSignals.map(\.dayKey))

        var staysByDayKey: [String: [DebugExportStayRecord]] = [:]
        for stay in records.stays {
            for dayKey in expandedDayKeys(for: stay, exportedAt: exportedAt) {
                allDayKeys.insert(dayKey)
                staysByDayKey[dayKey, default: []].append(stay)
            }
        }

        let presenceByDayKey = Dictionary(uniqueKeysWithValues: records.presenceDays.map { ($0.dayKey, $0) })
        let overridesByDayKey = Dictionary(uniqueKeysWithValues: records.dayOverrides.map { ($0.dayKey, $0) })
        let locationsByDayKey = Dictionary(grouping: records.locationSamples, by: \.dayKey)
        let photosByDayKey = Dictionary(grouping: records.photoSignals, by: \.dayKey)
        let calendarSignalsByDayKey = Dictionary(grouping: records.calendarSignals, by: \.dayKey)

        return allDayKeys
            .map { dayKey in
                let presence = presenceByDayKey[dayKey]
                let dayOverride = overridesByDayKey[dayKey]
                let stays = (staysByDayKey[dayKey] ?? []).sorted {
                    ($0.entryDayKey, $0.countryName, $0.enteredOn) < ($1.entryDayKey, $1.countryName, $1.enteredOn)
                }
                let locations = (locationsByDayKey[dayKey] ?? []).sorted {
                    ($0.timestamp, $0.sourceRaw, $0.countryName ?? "") < ($1.timestamp, $1.sourceRaw, $1.countryName ?? "")
                }
                let photos = (photosByDayKey[dayKey] ?? []).sorted {
                    ($0.timestamp, $0.assetIdHash) < ($1.timestamp, $1.assetIdHash)
                }
                let calendarSignals = (calendarSignalsByDayKey[dayKey] ?? []).sorted {
                    ($0.timestamp, $0.eventIdentifier) < ($1.timestamp, $1.eventIdentifier)
                }
                let timeZoneId = resolvedTimeZoneId(
                    presence: presence,
                    dayOverride: dayOverride,
                    stays: stays,
                    locations: locations,
                    photos: photos,
                    calendarSignals: calendarSignals
                )
                let timeZone = DayIdentity.canonicalTimeZone(preferredTimeZoneId: timeZoneId)
                let normalizedDate = DayKey.date(for: dayKey, timeZone: timeZone) ?? DayIdentity.normalizedDate(for: dayKey, dayTimeZoneId: timeZoneId)

                return DebugExportDaySnapshot(
                    dayKey: dayKey,
                    date: normalizedDate,
                    timeZoneId: timeZoneId,
                    presence: presence,
                    presenceSummary: presence.map(makePresenceSummary),
                    dayOverride: dayOverride,
                    staysCoveringDay: stays,
                    locations: locations,
                    photos: photos,
                    calendarSignals: calendarSignals,
                    sourceCounts: DebugExportDaySourceCounts(
                        stays: stays.count,
                        overrides: dayOverride == nil ? 0 : 1,
                        locations: locations.count,
                        photos: photos.count,
                        calendarSignals: calendarSignals.count
                    ),
                    hasAnyRawEvidence: !stays.isEmpty || dayOverride != nil || !locations.isEmpty || !photos.isEmpty || !calendarSignals.isEmpty
                )
            }
            .sorted {
                if $0.date == $1.date {
                    return $0.dayKey < $1.dayKey
                }
                return $0.date < $1.date
            }
    }

    private static func makePresenceSummary(_ presence: DebugExportPresenceDayRecord) -> DebugExportPresenceSummary {
        DebugExportPresenceSummary(
            countryCode: presence.countryCode,
            countryName: presence.countryName,
            suggestedCountryCode1: presence.suggestedCountryCode1,
            suggestedCountryName1: presence.suggestedCountryName1,
            suggestedCountryCode2: presence.suggestedCountryCode2,
            suggestedCountryName2: presence.suggestedCountryName2,
            contributedCountries: presence.contributedCountries,
            sourceLabels: presence.sourceLabels,
            confidence: presence.confidence,
            confidenceLabelRaw: presence.confidenceLabelRaw,
            isDisputed: presence.isDisputed,
            isManuallyModified: presence.isManuallyModified
        )
    }

    private static func expandedDayKeys(
        for stay: DebugExportStayRecord,
        exportedAt: Date
    ) -> [String] {
        let timeZone = DayIdentity.canonicalTimeZone(preferredTimeZoneId: stay.dayTimeZoneId)
        let startDate = DayKey.date(for: stay.entryDayKey, timeZone: timeZone) ?? stay.enteredOn
        let resolvedExitDayKey = stay.exitDayKey ?? DayKey.make(from: exportedAt, timeZone: timeZone)
        let endDate = DayKey.date(for: resolvedExitDayKey, timeZone: timeZone)
            ?? stay.exitedOn
            ?? DayKey.date(for: DayKey.make(from: exportedAt, timeZone: timeZone), timeZone: timeZone)
            ?? exportedAt

        guard startDate <= endDate else {
            return [stay.entryDayKey]
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var dayKeys: [String] = []
        var currentDate = startDate
        while currentDate <= endDate {
            dayKeys.append(DayKey.make(from: currentDate, timeZone: timeZone))
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        return dayKeys
    }

    private static func resolvedTimeZoneId(
        presence: DebugExportPresenceDayRecord?,
        dayOverride: DebugExportDayOverrideRecord?,
        stays: [DebugExportStayRecord],
        locations: [DebugExportLocationSampleRecord],
        photos: [DebugExportPhotoSignalRecord],
        calendarSignals: [DebugExportCalendarSignalRecord]
    ) -> String? {
        let candidates: [String?] = [
            presence?.timeZoneId,
            dayOverride?.dayTimeZoneId,
            stays.first?.dayTimeZoneId,
            locations.first?.timeZoneId,
            photos.first?.timeZoneId,
            calendarSignals.first?.bucketingTimeZoneId,
            calendarSignals.first?.timeZoneId
        ]

        return candidates.first { candidate in
            guard let candidate else { return false }
            return !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? TimeZone.current.identifier
    }

    private static func dateRange<T>(
        for items: [T],
        at keyPath: KeyPath<T, Date>
    ) -> DebugExportDateRange? {
        guard !items.isEmpty else { return nil }
        let dates = items.map { $0[keyPath: keyPath] }
        guard let earliest = dates.min(), let latest = dates.max() else { return nil }
        return DebugExportDateRange(earliest: earliest, latest: latest)
    }

    private static func dateRange<T>(
        for items: [T],
        dates: (T) -> [Date]
    ) -> DebugExportDateRange? {
        let flattenedDates = items.flatMap(dates)
        guard let earliest = flattenedDates.min(), let latest = flattenedDates.max() else { return nil }
        return DebugExportDateRange(earliest: earliest, latest: latest)
    }

    private static func sourceLabels(for sources: SignalSourceMask) -> [String] {
        var labels: [String] = []
        if sources.contains(.override) { labels.append("override") }
        if sources.contains(.stay) { labels.append("stay") }
        if sources.contains(.photo) { labels.append("photo") }
        if sources.contains(.location) { labels.append("location") }
        if sources.contains(.calendar) { labels.append("calendar") }
        return labels
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
