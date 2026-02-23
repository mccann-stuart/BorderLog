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
        let calendar = Calendar.current
        let timeZone = calendar.timeZone
        var dayKeySet = Set(dayKeys)

        let dateRange = self.dateRange(for: dayKeySet, timeZone: timeZone, calendar: calendar)
        let rangeStart = calendar.date(byAdding: .day, value: -1, to: dateRange.start) ?? dateRange.start
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: dateRange.end) ?? dateRange.end

        let stays: [Stay]
        let overrides: [DayOverride]
        let locations: [LocationSample]
        let photos: [PhotoSignal]

        do {
            stays = try dataFetcher.fetchStays(from: rangeStart, to: rangeEnd)
            overrides = try dataFetcher.fetchOverrides(from: rangeStart, to: rangeEnd)
            locations = try dataFetcher.fetchLocations(from: rangeStart, to: rangeEnd)
            photos = try dataFetcher.fetchPhotos(from: rangeStart, to: rangeEnd)
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

        dayKeySet.formUnion(locations.map { $0.dayKey })
        dayKeySet.formUnion(photos.map { $0.dayKey })

        for overrideDay in overrides {
            let overrideKey = DayKey.make(from: overrideDay.date, timeZone: timeZone)
            dayKeySet.insert(overrideKey)
        }

        let results = PresenceInferenceEngine.compute(
            dayKeys: dayKeySet,
            stays: stayInfos,
            overrides: overrideInfos,
            locations: locationInfos,
            photos: photoInfos,
            rangeEnd: rangeEnd,
            calendar: calendar
        )

        do {
            try self.upsertPresenceDays(results)
            try dataFetcher.save()
        } catch {
            print("LedgerRecomputeService save error: \(error)")
            onRecomputeError?(error)
        }
    }

    public func recomputeAll() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let earliest = (try? self.earliestSignalDate()) ?? calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let dayKeys = self.makeDayKeys(from: earliest, to: today, calendar: calendar)
        await self.recompute(dayKeys: dayKeys)
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

    private func dateRange(for dayKeys: Set<String>, timeZone: TimeZone, calendar: Calendar) -> (start: Date, end: Date) {
        let dates = dayKeys.compactMap { DayKey.date(for: $0, timeZone: timeZone) }
        let start = dates.min() ?? calendar.startOfDay(for: Date())
        let end = dates.max() ?? calendar.startOfDay(for: Date())
        return (start, end)
    }

    private func earliestSignalDate() throws -> Date? {
        let s = try dataFetcher.fetchEarliestStayDate()
        let o = try dataFetcher.fetchEarliestOverrideDate()
        let l = try dataFetcher.fetchEarliestLocationDate()
        let p = try dataFetcher.fetchEarliestPhotoDate()
        return [s, o, l, p].compactMap { $0 }.min()
    }
}
