import sys

def main():
    filepath = "Shared/DebugDataStoreExportService.swift"
    with open(filepath, 'r') as f:
        content = f.read()

    # Search for buildPayload definition
    search = """
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
                    accuracyQualityRaw: Self.locationAccuracyQuality(for: sample.accuracyMeters),
                    qualityFlags: Self.locationQualityFlags(for: sample.accuracyMeters),
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
                let evidencePhaseCounts = Self.evidencePhaseCounts(for: day.evidence)
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
                    suggestedCountryName2: day.suggestedCountryName2,
                    derivationReason: Self.derivationReason(for: day, evidencePhaseCounts: evidencePhaseCounts),
                    isContextualInference: evidencePhaseCounts.contextual > 0,
                    evidencePhaseCounts: evidencePhaseCounts
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
        )"""

    replace = """
    private enum ExportResult: Sendable {
        case stays([DebugExportStayRecord])
        case overrides([DebugExportDayOverrideRecord])
        case locations([DebugExportLocationSampleRecord])
        case photos([DebugExportPhotoSignalRecord])
        case calendars([DebugExportCalendarSignalRecord])
        case presences([DebugExportPresenceDayRecord], SchengenLedgerSummary)
        case configs([DebugExportCountryConfigRecord])
        case photoIngests([DebugExportPhotoIngestStateRecord])
    }

    func buildPayload(context: DebugExportRuntimeContext) async throws -> DebugDataStoreExportPayload {
        let exportedAt = context.metadata.exportedAt
        let container = self.modelContainer

        var stayRecords: [DebugExportStayRecord] = []
        var overrideRecords: [DebugExportDayOverrideRecord] = []
        var locationRecords: [DebugExportLocationSampleRecord] = []
        var photoRecords: [DebugExportPhotoSignalRecord] = []
        var calendarRecords: [DebugExportCalendarSignalRecord] = []
        var presenceRecords: [DebugExportPresenceDayRecord] = []
        var countryConfigRecords: [DebugExportCountryConfigRecord] = []
        var photoIngestStateRecords: [DebugExportPhotoIngestStateRecord] = []
        var schengenSummary: SchengenLedgerSummary?

        try await withThrowingTaskGroup(of: ExportResult.self) { group in
            group.addTask {
                let context = ModelContext(container)
                let stays = try context.fetch(FetchDescriptor<Stay>())
                let records = stays.map { stay in
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
                }.sorted {
                    ($0.entryDayKey, $0.countryName, $0.enteredOn) < ($1.entryDayKey, $1.countryName, $1.enteredOn)
                }
                return .stays(records)
            }

            group.addTask {
                let context = ModelContext(container)
                let overrides = try context.fetch(FetchDescriptor<DayOverride>())
                let records = overrides.map { override in
                    DebugExportDayOverrideRecord(
                        dayKey: override.dayKey,
                        dayTimeZoneId: override.dayTimeZoneId,
                        date: override.date,
                        countryName: override.countryName,
                        countryCode: override.countryCode,
                        regionRaw: override.regionRaw,
                        notes: override.notes
                    )
                }.sorted {
                    ($0.dayKey, $0.countryName) < ($1.dayKey, $1.countryName)
                }
                return .overrides(records)
            }

            group.addTask {
                let context = ModelContext(container)
                let locationSamples = try context.fetch(FetchDescriptor<LocationSample>())
                let records = locationSamples.map { sample in
                    DebugExportLocationSampleRecord(
                        timestamp: sample.timestamp,
                        latitude: sample.latitude,
                        longitude: sample.longitude,
                        accuracyMeters: sample.accuracyMeters,
                        accuracyQualityRaw: Self.locationAccuracyQuality(for: sample.accuracyMeters),
                        qualityFlags: Self.locationQualityFlags(for: sample.accuracyMeters),
                        sourceRaw: sample.sourceRaw,
                        dayKey: sample.dayKey,
                        timeZoneId: sample.timeZoneId,
                        countryCode: sample.countryCode,
                        countryName: sample.countryName
                    )
                }.sorted {
                    ($0.dayKey, $0.timestamp, $0.sourceRaw, $0.countryName ?? "") < ($1.dayKey, $1.timestamp, $1.sourceRaw, $1.countryName ?? "")
                }
                return .locations(records)
            }

            group.addTask {
                let context = ModelContext(container)
                let photoSignals = try context.fetch(FetchDescriptor<PhotoSignal>())
                let records = photoSignals.map { signal in
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
                }.sorted {
                    ($0.dayKey, $0.timestamp, $0.assetIdHash) < ($1.dayKey, $1.timestamp, $1.assetIdHash)
                }
                return .photos(records)
            }

            group.addTask {
                let context = ModelContext(container)
                let calendarSignals = try context.fetch(FetchDescriptor<CalendarSignal>())
                let records = calendarSignals.map { signal in
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
                }.sorted {
                    ($0.dayKey, $0.timestamp, $0.eventIdentifier) < ($1.dayKey, $1.timestamp, $1.eventIdentifier)
                }
                return .calendars(records)
            }

            group.addTask {
                let context = ModelContext(container)
                let presenceDays = try context.fetch(FetchDescriptor<PresenceDay>())
                let records = presenceDays.map { day in
                    let sourceMask = day.sources
                    let evidencePhaseCounts = Self.evidencePhaseCounts(for: day.evidence)
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
                        suggestedCountryName2: day.suggestedCountryName2,
                        derivationReason: Self.derivationReason(for: day, evidencePhaseCounts: evidencePhaseCounts),
                        isContextualInference: evidencePhaseCounts.contextual > 0,
                        evidencePhaseCounts: evidencePhaseCounts
                    )
                }.sorted {
                    ($0.dayKey, $0.countryName ?? "") < ($1.dayKey, $1.countryName ?? "")
                }
                let ledgerSummary = SchengenLedgerCalculator.summary(for: presenceDays, asOf: exportedAt)
                return .presences(records, ledgerSummary)
            }

            group.addTask {
                let context = ModelContext(container)
                let countryConfigs = try context.fetch(FetchDescriptor<CountryConfig>())
                let records = countryConfigs.map { config in
                    DebugExportCountryConfigRecord(countryCode: config.countryCode, maxAllowedDays: config.maxAllowedDays)
                }.sorted { $0.countryCode < $1.countryCode }
                return .configs(records)
            }

            group.addTask {
                let context = ModelContext(container)
                let photoIngestStates = try context.fetch(FetchDescriptor<PhotoIngestState>())
                let records = photoIngestStates.map { state in
                    DebugExportPhotoIngestStateRecord(
                        lastIngestedAt: state.lastIngestedAt,
                        lastAssetCreationDate: state.lastAssetCreationDate,
                        lastAssetIdHash: state.lastAssetIdHash,
                        fullScanCompleted: state.fullScanCompleted,
                        lastFullScanAt: state.lastFullScanAt
                    )
                }.sorted {
                    ($0.lastIngestedAt ?? .distantPast, $0.lastFullScanAt ?? .distantPast, $0.lastAssetIdHash ?? "") <
                    ($1.lastIngestedAt ?? .distantPast, $1.lastFullScanAt ?? .distantPast, $1.lastAssetIdHash ?? "")
                }
                return .photoIngests(records)
            }

            for try await result in group {
                switch result {
                case .stays(let records): stayRecords = records
                case .overrides(let records): overrideRecords = records
                case .locations(let records): locationRecords = records
                case .photos(let records): photoRecords = records
                case .calendars(let records): calendarRecords = records
                case .presences(let records, let ledgerSummary):
                    presenceRecords = records
                    schengenSummary = ledgerSummary
                case .configs(let records): countryConfigRecords = records
                case .photoIngests(let records): photoIngestStateRecords = records
                }
            }
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

        let resolvedSchengenSummary = schengenSummary!
        let summary = Self.makeSummary(
            records: records,
            schengenLedgerSummary: DebugExportSchengenLedgerSummary(
                usedDays: resolvedSchengenSummary.usedDays,
                remainingDays: resolvedSchengenSummary.remainingDays,
                overstayDays: resolvedSchengenSummary.overstayDays,
                unknownDays: resolvedSchengenSummary.unknownDays,
                windowStart: resolvedSchengenSummary.windowStart,
                windowEnd: resolvedSchengenSummary.windowEnd
            )
        )"""

    if search in content:
        content = content.replace(search, replace)

        search2 = """    func exportJSON(context: DebugExportRuntimeContext) throws -> Data {
        let payload = try buildPayload(context: context)"""
        replace2 = """    func exportJSON(context: DebugExportRuntimeContext) async throws -> Data {
        let payload = try await buildPayload(context: context)"""
        content = content.replace(search2, replace2)

        with open(filepath, 'w') as f:
            f.write(content)
        print("Successfully updated file")
    else:
        print("Search string not found")

if __name__ == "__main__":
    main()
