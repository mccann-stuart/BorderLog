//
//  LedgerRecomputeService.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import SwiftData

@MainActor
public final class LedgerRecomputeService {
    private let modelContext: ModelContext

    public init(modelContainer: ModelContainer) {
        self.modelContext = ModelContext(modelContainer)
    }

    public func recompute(dayKeys: [String]) async {
        let calendar = Calendar.current
        let timeZone = calendar.timeZone
        var dayKeySet = Set(dayKeys)

        let dateRange = self.dateRange(for: dayKeySet, timeZone: timeZone, calendar: calendar)
        let rangeStart = calendar.date(byAdding: .day, value: -1, to: dateRange.start) ?? dateRange.start
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: dateRange.end) ?? dateRange.end

        let stays = self.fetchStays(from: rangeStart, to: rangeEnd)
        let overrides = self.fetchOverrides(from: rangeStart, to: rangeEnd)
        let locations = self.fetchLocations(from: rangeStart, to: rangeEnd)
        let photos = self.fetchPhotos(from: rangeStart, to: rangeEnd)

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

        self.upsertPresenceDays(results)
    }

    public func recomputeAll() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let earliest = self.earliestSignalDate() ?? calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let dayKeys = self.makeDayKeys(from: earliest, to: today, calendar: calendar)
        await self.recompute(dayKeys: dayKeys)
    }

    private func upsertPresenceDays(_ results: [PresenceDayResult]) {
        let keys = results.map { $0.dayKey }
        let descriptor = FetchDescriptor<PresenceDay>()
        let existing = (try? self.modelContext.fetch(descriptor))?.filter { keys.contains($0.dayKey) } ?? []
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
                    locationCount: result.locationCount
                )
                self.modelContext.insert(newDay)
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

    private func earliestSignalDate() -> Date? {
        let s = self.fetchEarliestStayDate()
        let o = self.fetchEarliestOverrideDate()
        let l = self.fetchEarliestLocationDate()
        let p = self.fetchEarliestPhotoDate()
        return [s, o, l, p].compactMap { $0 }.min()
    }

    private func fetchStays(from start: Date, to end: Date) -> [Stay] {
        let distantFuture = Date.distantFuture
        let descriptor = FetchDescriptor<Stay>(
            predicate: #Predicate { stay in
                stay.enteredOn <= end && (stay.exitedOn ?? distantFuture) >= start
            }
        )
        return (try? self.modelContext.fetch(descriptor)) ?? []
    }

    private func fetchOverrides(from start: Date, to end: Date) -> [DayOverride] {
        let descriptor = FetchDescriptor<DayOverride>()
        let overrides = (try? self.modelContext.fetch(descriptor)) ?? []
        return overrides.filter { $0.date >= start && $0.date <= end }
    }

    private func fetchLocations(from start: Date, to end: Date) -> [LocationSample] {
        let descriptor = FetchDescriptor<LocationSample>(
            predicate: #Predicate { sample in
                sample.timestamp >= start && sample.timestamp <= end
            }
        )
        return (try? self.modelContext.fetch(descriptor)) ?? []
    }

    private func fetchPhotos(from start: Date, to end: Date) -> [PhotoSignal] {
        let descriptor = FetchDescriptor<PhotoSignal>(
            predicate: #Predicate { signal in
                signal.timestamp >= start && signal.timestamp <= end
            }
        )
        return (try? self.modelContext.fetch(descriptor)) ?? []
    }

    private func fetchEarliestStayDate() -> Date? {
        let descriptor = FetchDescriptor<Stay>()
        let stays = (try? self.modelContext.fetch(descriptor)) ?? []
        return stays.map { $0.enteredOn }.min()
    }

    private func fetchEarliestOverrideDate() -> Date? {
        let descriptor = FetchDescriptor<DayOverride>()
        let overrides = (try? self.modelContext.fetch(descriptor)) ?? []
        return overrides.map { $0.date }.min()
    }

    private func fetchEarliestLocationDate() -> Date? {
        var descriptor = FetchDescriptor<LocationSample>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        descriptor.fetchLimit = 1
        return (try? self.modelContext.fetch(descriptor))?.first?.timestamp
    }

    private func fetchEarliestPhotoDate() -> Date? {
        var descriptor = FetchDescriptor<PhotoSignal>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        descriptor.fetchLimit = 1
        return (try? self.modelContext.fetch(descriptor))?.first?.timestamp
    }
}
