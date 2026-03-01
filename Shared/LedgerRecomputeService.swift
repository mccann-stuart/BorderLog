//
//  LedgerRecomputeService.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import SwiftData

@ModelActor
public actor LedgerRecomputeService {
    internal var _dataFetcher: LedgerDataFetching?
    internal var onRecomputeError: ((Error) -> Void)?

    private var dataFetcher: LedgerDataFetching {
        if let _dataFetcher { return _dataFetcher }
        let fetcher = RealLedgerDataFetcher(modelContext: modelContext)
        _dataFetcher = fetcher
        return fetcher
    }

    public func recompute(dayKeys: [String]) async {
        var didBeginInference = false
        defer {
            if didBeginInference {
                Task { @MainActor in
                    InferenceActivity.shared.endInference()
                }
            }
        }
        guard !dayKeys.isEmpty else { return }

        let calendar = Calendar.current
        let timeZone = calendar.timeZone
        let scope: (start: Date, end: Date, dayKeys: [String])
        do {
            guard let expandedScope = try self.makeImpactedScope(
                seedDayKeys: Set(dayKeys),
                timeZone: timeZone,
                calendar: calendar
            ) else {
                return
            }
            scope = expandedScope
        } catch {
            print("LedgerRecomputeService scope error: \(error)")
            onRecomputeError?(error)
            return
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
            overrides = try dataFetcher.fetchOverrides(from: rangeStart, to: rangeEnd)
            locations = try dataFetcher.fetchLocations(from: rangeStart, to: rangeEnd)
            photos = try dataFetcher.fetchPhotos(from: rangeStart, to: rangeEnd)
            calendarSignals = try dataFetcher.fetchCalendarSignals(from: rangeStart, to: rangeEnd)
        } catch {
            print("LedgerRecomputeService fetch error: \(error)")
            onRecomputeError?(error)
            return
        }

        let stayInfos = stays.map {
            StayPresenceInfo(
                enteredOn: $0.enteredOn,
                exitedOn: $0.exitedOn,
                countryCode: $0.countryCode,
                countryName: $0.countryName
            )
        }

        let overrideInfos = overrides.map {
            OverridePresenceInfo(
                date: $0.date,
                countryCode: $0.countryCode,
                countryName: $0.countryName
            )
        }

        let locationInfos = locations.compactMap { sample -> LocationSignalInfo? in
            guard let name = sample.countryName ?? sample.countryCode else { return nil }
            return LocationSignalInfo(
                dayKey: sample.dayKey,
                countryCode: sample.countryCode ?? name,
                countryName: name,
                accuracyMeters: sample.accuracyMeters,
                timeZoneId: sample.timeZoneId
            )
        }

        let photoInfos = photos.compactMap { signal -> PhotoSignalInfo? in
            guard let name = signal.countryName ?? signal.countryCode else { return nil }
            return PhotoSignalInfo(
                dayKey: signal.dayKey,
                countryCode: signal.countryCode ?? name,
                countryName: name,
                timeZoneId: signal.timeZoneId
            )
        }

        let calendarInfos = calendarSignals.compactMap { signal -> CalendarSignalInfo? in
            guard let name = signal.countryName ?? signal.countryCode else { return nil }
            return CalendarSignalInfo(
                dayKey: signal.dayKey,
                countryCode: signal.countryCode ?? name,
                countryName: name,
                timeZoneId: signal.timeZoneId
            )
        }

        let totalDayKeys = dayKeySet.count
        await MainActor.run {
            InferenceActivity.shared.beginInference(totalDays: totalDayKeys)
        }
        didBeginInference = true

        let results = await PresenceInferenceEngine.compute(
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

        do {
            try self.upsertPresenceDays(results)
            try await dataFetcher.save()
        } catch {
            print("LedgerRecomputeService save error: \(error)")
            onRecomputeError?(error)
        }
    }

    public func recomputeAll() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: today) ?? today
        let earliestSignal = try? self.earliestSignalDate()

        // Ensure we cover at least the last 2 years, or earlier if data exists
        let earliest = [earliestSignal, twoYearsAgo].compactMap { $0 }.min() ?? twoYearsAgo

        let dayKeys = self.makeDayKeys(from: earliest, to: today, calendar: calendar)
        await self.recompute(dayKeys: dayKeys)
    }

    /// Ensures every calendar day from two years ago (rolling) to today
    /// has a PresenceDay entry in the store. Missing days are inserted as unknown/empty.
    public func fillMissingDays(asOf: Date = Date(), calendar: Calendar = .current) async {
        let timeZone = calendar.timeZone
        let today = calendar.startOfDay(for: asOf)
        let start = calendar.date(byAdding: .year, value: -2, to: today) ?? today

        let allDayKeys = Set(self.makeDayKeys(from: start, to: today, calendar: calendar))

        let existingKeys: Set<String>
        do {
            // Optimization: Fetch only keys for the relevant 2-year window (plus today) instead of all keys in the database.
            existingKeys = try await dataFetcher.fetchPresenceDayKeys(from: start, to: today)
        } catch {
            print("LedgerRecomputeService fillMissingDays fetch error: \(error)")
            return
        }

        let missing = allDayKeys.subtracting(existingKeys)
        guard !missing.isEmpty else { return }

        for dayKey in missing {
            let date = await DayKey.date(for: dayKey, timeZone: timeZone) ?? today
            let day = await PresenceDay(
                dayKey: dayKey,
                date: date,
                timeZoneId: timeZone.identifier,
                countryCode: nil,
                countryName: nil,
                confidence: 0,
                confidenceLabel: .low,
                sources: .none,
                isOverride: false,
                stayCount: 0,
                photoCount: 0,
                locationCount: 0,
                calendarCount: 0
            )
            await dataFetcher.insertPresenceDay(day)
        }

        do {
            try await dataFetcher.save()
        } catch {
            print("LedgerRecomputeService fillMissingDays save error: \(error)")
        }
    }

    private func upsertPresenceDays(_ results: [PresenceDayResult]) throws {
        let keys = results.map { $0.dayKey }
        let existing = try dataFetcher.fetchPresenceDays(keys: keys)
        var existingMap: [String: PresenceDay] = [:]
        for item in existing {
            existingMap[item.dayKey] = item
        }

        for result in results {
            if let existing = existingMap[result.dayKey] {
                existing.date = result.date
                existing.timeZoneId = result.timeZoneId
                existing.countryCode = result.countryCode
                existing.countryName = result.countryName
                existing.confidence = result.confidence
                existing.confidenceLabel = result.confidenceLabel
                existing.sources = result.sources
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
                    countryCode: result.countryCode,
                    countryName: result.countryName,
                    confidence: result.confidence,
                    confidenceLabel: result.confidenceLabel,
                    sources: result.sources,
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

    private func makeImpactedScope(
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

        let paddingDays = 8
        let paddedStart = calendar.date(byAdding: .day, value: -paddingDays, to: mutationStart) ?? mutationStart
        let paddedEnd = calendar.date(byAdding: .day, value: paddingDays, to: mutationEnd) ?? mutationEnd

        let today = calendar.startOfDay(for: Date())
        let lowerBound = try self.coverageLowerBound(today: today, calendar: calendar)

        var scopeStart = max(paddedStart, lowerBound)
        var scopeEnd = min(paddedEnd, today)
        if scopeStart > scopeEnd {
            // Clamp out-of-bound seeds to the nearest valid in-range day.
            if mutationEnd < lowerBound {
                scopeStart = lowerBound
                scopeEnd = lowerBound
            } else if mutationStart > today {
                scopeStart = today
                scopeEnd = today
            } else {
                return nil
            }
        }

        if let leftAnchor = try dataFetcher.fetchNearestKnownPresenceDay(before: scopeStart) {
            scopeStart = max(calendar.startOfDay(for: leftAnchor.date), lowerBound)
        }
        if let rightAnchor = try dataFetcher.fetchNearestKnownPresenceDay(after: scopeEnd) {
            scopeEnd = min(calendar.startOfDay(for: rightAnchor.date), today)
        }
        guard scopeStart <= scopeEnd else { return nil }

        return (
            start: scopeStart,
            end: scopeEnd,
            dayKeys: makeDayKeys(from: scopeStart, to: scopeEnd, calendar: calendar)
        )
    }

    private func coverageLowerBound(today: Date, calendar: Calendar) throws -> Date {
        let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: today) ?? today
        let earliestSignal = try earliestSignalDate().map { calendar.startOfDay(for: $0) }
        return [earliestSignal, twoYearsAgo].compactMap { $0 }.min() ?? twoYearsAgo
    }

    private func earliestSignalDate() throws -> Date? {
        let s = try dataFetcher.fetchEarliestStayDate()
        let o = try dataFetcher.fetchEarliestOverrideDate()
        let l = try dataFetcher.fetchEarliestLocationDate()
        let p = try dataFetcher.fetchEarliestPhotoDate()
        let c = try dataFetcher.fetchEarliestCalendarSignalDate()
        return [s, o, l, p, c].compactMap { $0 }.min()
    }

}
