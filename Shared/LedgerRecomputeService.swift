//
//  LedgerRecomputeService.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
@preconcurrency import SwiftData
import os

enum LedgerRecomputeError: LocalizedError {
    case noValidDayKeys([String])

    var errorDescription: String? {
        switch self {
        case .noValidDayKeys(let dayKeys):
            return "Ledger recompute could not resolve any requested day keys: \(dayKeys.sorted().joined(separator: ", "))."
        }
    }
}

@ModelActor
public actor LedgerRecomputeService {
    private static let sourceReconciliationVersion = 1
    internal var _dataFetcher: LedgerDataFetching?
    internal var _recoveryStore: LedgerRecomputeRecoveryStore?
    private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "LedgerRecomputeService")
    internal var onRecomputeError: ((Error) -> Void)?

    private var dataFetcher: LedgerDataFetching {
        if let _dataFetcher { return _dataFetcher }
        let fetcher = RealLedgerDataFetcher(modelContext: modelContext)
        _dataFetcher = fetcher
        return fetcher
    }

    private var recoveryStore: LedgerRecomputeRecoveryStore {
        _recoveryStore ?? .shared
    }

    public func recompute(dayKeys: [String]) async throws {
        var didBeginInference = false
        defer {
            if didBeginInference {
                Task { @MainActor in
                    InferenceActivity.shared.endInference()
                }
            }
        }
        guard !dayKeys.isEmpty else { return }

        // Record the work before touching the ledger. If the process exits or any fetch/save
        // fails, launch reconciliation will retry these keys.
        let completionToken = recoveryStore.markDirty(dayKeys: dayKeys)

        let calendar = Calendar.current
        let timeZone = calendar.timeZone
        
        var currentSeedDayKeys = Set(dayKeys)
        var stable = false
        var finalResults: [PresenceDayResult] = []
        var finalScopeKeys: [String] = []
        
        // Loop up to 15 times max to prevent infinite cascading, normally stabilizes in 1-2 passes
        var passCount = 0
        
        while !stable && passCount < 15 {
            passCount += 1
            
            let scope: (start: Date, end: Date, dayKeys: [String])
            do {
                guard let expandedScope = try self.makeImmediateImpactScope(
                    seedDayKeys: currentSeedDayKeys,
                    timeZone: timeZone,
                    calendar: calendar
                ) else {
                    throw LedgerRecomputeError.noValidDayKeys(Array(currentSeedDayKeys))
                }
                scope = expandedScope
            } catch {
                Self.logger.error("LedgerRecomputeService scope error: \(error, privacy: .private)")
                onRecomputeError?(error)
                throw error
            }

            let dayKeySet = Set(scope.dayKeys)
            guard !dayKeySet.isEmpty else { return }

            // Fetch one day on each side so timestamp-based evidence near midnight is available.
            let rangeStart = calendar.date(byAdding: .day, value: -1, to: scope.start) ?? scope.start
            let rangeEnd = calendar.date(byAdding: .day, value: 1, to: scope.end) ?? scope.end

            let stays: [Stay]
            let overrides: [DayOverride]
            let locations: [LocationSample]
            let photos: [PhotoSignal]
            let calendarSignals: [CalendarSignal]

            do {
                stays = try dataFetcher.fetchStays(from: rangeStart, to: rangeEnd)
                overrides = try dataFetcher.fetchOverrides(dayKeys: Array(dayKeySet))
                locations = try dataFetcher.fetchLocations(from: rangeStart, to: rangeEnd)
                photos = try dataFetcher.fetchPhotos(from: rangeStart, to: rangeEnd)
                calendarSignals = try dataFetcher.fetchCalendarSignals(from: rangeStart, to: rangeEnd)
            } catch {
                Self.logger.error("LedgerRecomputeService fetch error: \(error, privacy: .private)")
                onRecomputeError?(error)
                throw error
            }

            let stayInfos = stays.map {
                StayPresenceInfo(
                    entryDayKey: $0.entryDayKey,
                    exitDayKey: $0.exitDayKey,
                    dayTimeZoneId: $0.dayTimeZoneId,
                    countryCode: $0.countryCode,
                    countryName: $0.countryName
                )
            }

            let overrideInfos = overrides.map {
                OverridePresenceInfo(
                    dayKey: $0.dayKey,
                    dayTimeZoneId: $0.dayTimeZoneId,
                    countryCode: $0.countryCode,
                    countryName: $0.countryName
                )
            }

            let locationInfos = locations.compactMap { sample -> LocationSignalInfo? in
                guard let name = sample.countryName ?? sample.countryCode else { return nil }
                return LocationSignalInfo(
                    dayKey: sample.dayKey,
                    countryCode: sample.countryCode,
                    countryName: name,
                    accuracyMeters: sample.accuracyMeters,
                    timeZoneId: sample.timeZoneId,
                    timestamp: sample.timestamp,
                    sourceRaw: sample.sourceRaw
                )
            }

            let photoInfos = photos.compactMap { signal -> PhotoSignalInfo? in
                guard let name = signal.countryName ?? signal.countryCode else { return nil }
                return PhotoSignalInfo(
                    dayKey: signal.dayKey,
                    countryCode: signal.countryCode,
                    countryName: name,
                    timeZoneId: signal.timeZoneId
                )
            }

            let calendarInfos = calendarSignals.compactMap { signal -> CalendarSignalInfo? in
                guard let name = signal.countryName ?? signal.countryCode else { return nil }
                return CalendarSignalInfo(
                    dayKey: signal.dayKey,
                    countryCode: signal.countryCode,
                    countryName: name,
                    timeZoneId: signal.timeZoneId,
                    bucketingTimeZoneId: signal.bucketingTimeZoneId,
                    eventIdentifier: signal.eventIdentifier,
                    source: signal.source
                )
            }

            if !didBeginInference {
                let totalDayKeys = dayKeySet.count
                await MainActor.run { InferenceActivity.shared.beginInference(totalDays: totalDayKeys) }
                didBeginInference = true
            }

            let results = PresenceInferenceEngine.compute(
                dayKeys: dayKeySet,
                stays: stayInfos,
                overrides: overrideInfos,
                locations: locationInfos,
                photos: photoInfos,
                calendarSignals: calendarInfos,
                rangeEnd: scope.end,
                calendar: calendar,
                progress: { processed, total in
                    Task { @MainActor in
                        InferenceActivity.shared.updateInferenceProgress(processedDays: processed)
                    }
                }
            )
            
            // Incremental dependency check: Have the boundary days changed their primary result?
            let existingDays: [PresenceDay]
            do {
                existingDays = try dataFetcher.fetchPresenceDays(keys: Array(dayKeySet))
            } catch {
                Self.logger.error("LedgerRecomputeService existing-day fetch error: \(error, privacy: .private)")
                onRecomputeError?(error)
                throw error
            }
            let existingMap = existingDays.reduce(into: [String: PresenceDay](minimumCapacity: existingDays.count)) { $0[$1.dayKey] = $1 }
            
            var needsExpansion = false
            for result in results {
                let existing = existingMap[result.dayKey]
                let previousCode = existing?.contributedCountries.first?.countryCode
                let newCode = result.contributedCountries.first?.countryCode
                
                if previousCode != newCode || passCount == 1 {
                    // Result changed, we should include neighbors to see if it cascades
                    // (But to optimize, we only expand if it's currently on the edge of the scope)
                    if let date = DayKey.date(for: result.dayKey, timeZone: timeZone) {
                        let prevDay = calendar.date(byAdding: .day, value: -1, to: date)!
                        let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
                        let prevKey = DayKey.make(from: prevDay, timeZone: timeZone)
                        let nextKey = DayKey.make(from: nextDay, timeZone: timeZone)
                        
                        if !currentSeedDayKeys.contains(prevKey) {
                            currentSeedDayKeys.insert(prevKey)
                            needsExpansion = true
                        }
                        if !currentSeedDayKeys.contains(nextKey) {
                            currentSeedDayKeys.insert(nextKey)
                            needsExpansion = true
                        }
                    }
                }
            }
            
            stable = !needsExpansion
            if stable || passCount == 15 {
                finalResults = results
                finalScopeKeys = scope.dayKeys
            }
        }

        do {
            try self.upsertPresenceDays(finalResults, originalKeys: finalScopeKeys)
            try dataFetcher.save()
            await DiagnosticsStore.shared.recordSuccessfulRecompute()
            recoveryStore.clearDirty(matching: completionToken)
        } catch {
            Self.logger.error("LedgerRecomputeService save error: \(error, privacy: .private)")
            onRecomputeError?(error)
            throw error
        }
    }

    public func recomputeAll() async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: today) ?? today
        let earliestSignal = try self.earliestSignalDate()

        // ⚡ Bolt: Avoid intermediate O(N) array allocation from .compactMap { $0 }.min()
        var earliest = twoYearsAgo
        if let earliestSignal = earliestSignal, earliestSignal < earliest {
            earliest = earliestSignal
        }

        let dayKeys = self.makeDayKeys(from: earliest, to: today, calendar: calendar)
        try await self.recompute(dayKeys: dayKeys)
    }

    /// Repairs work interrupted after a source save and refreshes every day currently backed
    /// by source data. Running this on launch also repairs older builds that saved signals but
    /// failed to update their derived ledger rows.
    public func reconcileDirtyAndExistingSourceDays(asOf: Date = Date()) async throws {
        let dirtyDayKeys = recoveryStore.dirtyDayKeys()
        let shouldReconcileSources = recoveryStore.needsSourceReconciliation(
            version: Self.sourceReconciliationVersion
        )

        let sourceDayKeys: Set<String>
        if shouldReconcileSources {
            do {
                sourceDayKeys = try existingSourceDayKeys(asOf: asOf)
            } catch {
                Self.logger.error("LedgerRecomputeService reconciliation fetch error: \(error, privacy: .private)")
                onRecomputeError?(error)
                throw error
            }
        } else {
            sourceDayKeys = []
        }

        let dayKeys = dirtyDayKeys.union(sourceDayKeys)
        if !dayKeys.isEmpty {
            try await recompute(dayKeys: Array(dayKeys))
        }
        if shouldReconcileSources {
            recoveryStore.recordSourceReconciliation(version: Self.sourceReconciliationVersion)
        }
    }

    public func fillMissingDays(asOf: Date = Date(), calendar: Calendar = .current) async {
        let timeZone = calendar.timeZone
        let today = calendar.startOfDay(for: asOf)
        let start = calendar.date(byAdding: .year, value: -2, to: today) ?? today

        let allDayKeys = Set(self.makeDayKeys(from: start, to: today, calendar: calendar))

        let existingKeys: Set<String>
        do {
            existingKeys = try dataFetcher.fetchPresenceDayKeys(in: allDayKeys)
        } catch {
            Self.logger.error("LedgerRecomputeService fillMissingDays fetch error: \(error, privacy: .private)")
            return
        }

        let missing = allDayKeys.subtracting(existingKeys)
        guard !missing.isEmpty else { return }

        for dayKey in missing.sorted() {
            let date = DayKey.date(for: dayKey, timeZone: timeZone) ?? today
            let day = PresenceDay(
                dayKey: dayKey,
                date: date,
                timeZoneId: timeZone.identifier,
                countryAllocations: [],
                zoneOverlays: [],
                evidenceEntries: [],
                confidenceBreakdown: PresenceConfidenceBreakdown(
                    score: 0,
                    runnerUpScore: 0,
                    margin: 0,
                    normalizedWinningShare: 0,
                    label: .low,
                    calibrationSummary: "empty"
                ),
                sourceSummary: .none,
                isOverride: false,
                stayCount: 0,
                photoCount: 0,
                locationCount: 0,
                calendarCount: 0
            )
            dataFetcher.insertPresenceDay(day)
        }

        do {
            try dataFetcher.save()
        } catch {
            Self.logger.error("LedgerRecomputeService fillMissingDays save error: \(error, privacy: .private)")
        }
    }

    internal func setRecoveryStore(_ store: LedgerRecomputeRecoveryStore) {
        _recoveryStore = store
    }

    private func upsertPresenceDays(_ results: [PresenceDayResult], originalKeys: [String]) throws {
        let keys = results.map { $0.dayKey }
        let existing = try dataFetcher.fetchPresenceDays(keys: keys)
        let existingMap = existing.reduce(into: [String: PresenceDay](minimumCapacity: existing.count)) { $0[$1.dayKey] = $1 }

        for result in results {
            if let existing = existingMap[result.dayKey] {
                existing.date = result.date
                existing.timeZoneId = result.timeZoneId
                existing.countryAllocations = result.countryAllocations
                existing.zoneOverlays = result.zoneOverlays
                existing.evidenceEntries = result.evidenceEntries
                existing.confidenceBreakdown = result.confidenceBreakdown
                existing.sourceSummary = result.sourceSummary
                existing.isOverride = result.isOverride
                existing.stayCount = result.stayCount
                existing.photoCount = result.photoCount
                existing.locationCount = result.locationCount
                existing.calendarCount = result.calendarCount
                existing.isDisputed = result.isDisputed
                existing.suggestedCountryCode1 = result.suggestedCountryCode1
                existing.suggestedCountryName1 = result.suggestedCountryName1
                existing.suggestedCountryCode2 = result.suggestedCountryCode2
                existing.suggestedCountryName2 = result.suggestedCountryName2
            } else {
                let newDay = PresenceDay(
                    dayKey: result.dayKey,
                    date: result.date,
                    timeZoneId: result.timeZoneId,
                    countryAllocations: result.countryAllocations,
                    zoneOverlays: result.zoneOverlays,
                    evidenceEntries: result.evidenceEntries,
                    confidenceBreakdown: result.confidenceBreakdown,
                    sourceSummary: result.sourceSummary,
                    isOverride: result.isOverride,
                    stayCount: result.stayCount,
                    photoCount: result.photoCount,
                    locationCount: result.locationCount,
                    calendarCount: result.calendarCount,
                    isDisputed: result.isDisputed,
                    suggestedCountryCode1: result.suggestedCountryCode1,
                    suggestedCountryName1: result.suggestedCountryName1,
                    suggestedCountryCode2: result.suggestedCountryCode2,
                    suggestedCountryName2: result.suggestedCountryName2
                )
                dataFetcher.insertPresenceDay(newDay)
            }
        }
    }

    private func makeDayKeys(from start: Date, to end: Date, calendar: Calendar) -> [String] {
        let timeZone = calendar.timeZone
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else { return [] }

        var day = startDay
        var keys: [String] = []
        while day <= endDay {
            keys.append(DayKey.make(from: day, timeZone: timeZone))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return keys
    }

    private func makeImmediateImpactScope(
        seedDayKeys: Set<String>,
        timeZone: TimeZone,
        calendar: Calendar
    ) throws -> (start: Date, end: Date, dayKeys: [String])? {
        let mutationDates = seedDayKeys.compactMap { dayKey -> Date? in
            guard let date = DayKey.date(for: dayKey, timeZone: timeZone) else { return nil }
            return calendar.startOfDay(for: date)
        }
        guard let mutationStart = mutationDates.min(), let mutationEnd = mutationDates.max() else {
            return nil
        }

        let today = calendar.startOfDay(for: Date())
        var scopeStart = mutationStart
        var scopeEnd = min(mutationEnd, today)
        if scopeStart > scopeEnd {
            if mutationStart > today {
                scopeStart = today
                scopeEnd = today
            } else {
                return nil
            }
        }

        return (
            start: scopeStart,
            end: scopeEnd,
            dayKeys: makeDayKeys(from: scopeStart, to: scopeEnd, calendar: calendar)
        )
    }

    private func earliestSignalDate() throws -> Date? {
        let s = try dataFetcher.fetchEarliestStayDate()
        let o = try dataFetcher.fetchEarliestOverrideDate()
        let l = try dataFetcher.fetchEarliestLocationDate()
        let p = try dataFetcher.fetchEarliestPhotoDate()
        let c = try dataFetcher.fetchEarliestCalendarSignalDate()

        // ⚡ Bolt: Avoid unnecessary O(N) intermediate array allocation when calculating min() over optional properties
        var minDate: Date? = nil
        for date in [s, o, l, p, c] {
            if let d = date {
                if let currentMin = minDate {
                    if d < currentMin { minDate = d }
                } else {
                    minDate = d
                }
            }
        }
        return minDate
    }

    private func existingSourceDayKeys(asOf: Date) throws -> Set<String> {
        guard let earliestSignalDate = try earliestSignalDate() else { return [] }

        let calendar = Calendar.current
        let rangeStart = calendar.startOfDay(for: earliestSignalDate)
        let rangeEnd = max(asOf, rangeStart)

        let stays = try dataFetcher.fetchStays(from: rangeStart, to: rangeEnd)
        let overrides = try dataFetcher.fetchOverrides(from: rangeStart, to: rangeEnd)
        let locations = try dataFetcher.fetchLocations(from: rangeStart, to: rangeEnd)
        let photos = try dataFetcher.fetchPhotos(from: rangeStart, to: rangeEnd)
        let calendarSignals = try dataFetcher.fetchCalendarSignals(from: rangeStart, to: rangeEnd)

        var dayKeys = Set(overrides.lazy.map(\.dayKey))
        dayKeys.formUnion(locations.lazy.map(\.dayKey))
        dayKeys.formUnion(photos.lazy.map(\.dayKey))
        dayKeys.formUnion(calendarSignals.lazy.map(\.dayKey))

        for stay in stays {
            let timeZone = DayIdentity.canonicalTimeZone(
                preferredTimeZoneId: stay.dayTimeZoneId,
                fallback: calendar.timeZone
            )
            var stayCalendar = Calendar(identifier: .gregorian)
            stayCalendar.timeZone = timeZone

            guard let startDate = DayKey.date(for: stay.entryDayKey, timeZone: timeZone) else {
                dayKeys.insert(stay.entryDayKey)
                continue
            }
            let endDayKey = stay.exitDayKey ?? DayKey.make(from: asOf, timeZone: timeZone)
            let endDate = DayKey.date(for: endDayKey, timeZone: timeZone) ?? startDate

            var date = min(startDate, endDate)
            let finalDate = max(startDate, endDate)
            while date <= finalDate {
                dayKeys.insert(DayKey.make(from: date, timeZone: timeZone))
                guard let nextDate = stayCalendar.date(byAdding: .day, value: 1, to: date) else { break }
                date = nextDate
            }
        }

        return dayKeys
    }
}
