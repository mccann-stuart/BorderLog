//
//  LedgerRecomputeService.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import SwiftData

@MainActor
enum LedgerRecomputeService {
    static func recompute(dayKeys: [String], modelContext: ModelContext) async {
        let calendar = Calendar.current
        let timeZone = calendar.timeZone
        var dayKeySet = Set(dayKeys)

        let dateRange = dateRange(for: dayKeySet, timeZone: timeZone, calendar: calendar)
        let rangeStart = calendar.date(byAdding: .day, value: -1, to: dateRange.start) ?? dateRange.start
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: dateRange.end) ?? dateRange.end

        let stays = fetchStays(from: rangeStart, to: rangeEnd, modelContext: modelContext)
        let overrides = fetchOverrides(from: rangeStart, to: rangeEnd, modelContext: modelContext)
        let locations = fetchLocations(from: rangeStart, to: rangeEnd, modelContext: modelContext)
        let photos = fetchPhotos(from: rangeStart, to: rangeEnd, modelContext: modelContext)

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

        upsertPresenceDays(results, modelContext: modelContext)
    }

    static func recomputeAll(modelContext: ModelContext) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let earliest = earliestSignalDate(modelContext: modelContext) ?? calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let dayKeys = makeDayKeys(from: earliest, to: today, calendar: calendar)
        await recompute(dayKeys: dayKeys, modelContext: modelContext)
    }

    private static func upsertPresenceDays(_ results: [PresenceDayResult], modelContext: ModelContext) {
        let keys = results.map { $0.dayKey }
        let descriptor = FetchDescriptor<PresenceDay>()
        let existing = (try? modelContext.fetch(descriptor))?.filter { keys.contains($0.dayKey) } ?? []
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
                modelContext.insert(newDay)
            }
        }
    }

    private static func makeDayKeys(from start: Date, to end: Date, calendar: Calendar) -> [String] {
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

    private static func dateRange(for dayKeys: Set<String>, timeZone: TimeZone, calendar: Calendar) -> (start: Date, end: Date) {
        let dates = dayKeys.compactMap { DayKey.date(for: $0, timeZone: timeZone) }
        let start = dates.min() ?? calendar.startOfDay(for: Date())
        let end = dates.max() ?? calendar.startOfDay(for: Date())
        return (start, end)
    }

    private static func earliestSignalDate(modelContext: ModelContext) -> Date? {
        // Optimization: Fetch only the earliest record for each type using database-level sorting and limiting,
        // rather than fetching all records into memory to find the minimum.
        let stayDate = fetchEarliestDate(for: Stay.self, sortBy: \.enteredOn, modelContext: modelContext)
        let overrideDate = fetchEarliestDate(for: DayOverride.self, sortBy: \.date, modelContext: modelContext)
        let locationDate = fetchEarliestDate(for: LocationSample.self, sortBy: \.timestamp, modelContext: modelContext)
        let photoDate = fetchEarliestDate(for: PhotoSignal.self, sortBy: \.timestamp, modelContext: modelContext)

        return [stayDate, overrideDate, locationDate, photoDate].compactMap { $0 }.min()
    }

    private static func fetchEarliestDate<T: PersistentModel>(
        for type: T.Type,
        sortBy keyPath: KeyPath<T, Date>,
        modelContext: ModelContext
    ) -> Date? {
        var descriptor = FetchDescriptor<T>(sortBy: [SortDescriptor(keyPath, order: .forward)])
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first?[keyPath: keyPath]
    }

    private static func fetchStays(from start: Date, to end: Date, modelContext: ModelContext) -> [Stay] {
        // Optimization: Use a predicate to filter stays at the database level instead of fetching all and filtering in memory.
        // Logic: stay starts before range ends AND stay ends after range starts (or is ongoing).
        let descriptor = FetchDescriptor<Stay>(
            predicate: #Predicate { stay in
                stay.enteredOn <= end && (stay.exitedOn == nil || stay.exitedOn! >= start)
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private static func fetchOverrides(from start: Date, to end: Date, modelContext: ModelContext) -> [DayOverride] {
        let descriptor = FetchDescriptor<DayOverride>(
            predicate: #Predicate { override in
                override.date >= start && override.date <= end
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private static func fetchLocations(from start: Date, to end: Date, modelContext: ModelContext) -> [LocationSample] {
        let descriptor = FetchDescriptor<LocationSample>(
            predicate: #Predicate { sample in
                sample.timestamp >= start && sample.timestamp <= end
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private static func fetchPhotos(from start: Date, to end: Date, modelContext: ModelContext) -> [PhotoSignal] {
        let descriptor = FetchDescriptor<PhotoSignal>(
            predicate: #Predicate { signal in
                signal.timestamp >= start && signal.timestamp <= end
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
