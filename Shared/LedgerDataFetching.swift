//
//  LedgerDataFetching.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
@preconcurrency import SwiftData

protocol LedgerDataFetching {
    nonisolated func fetchStays(from start: Date, to end: Date) throws -> [Stay]
    nonisolated func fetchOverrides(from start: Date, to end: Date) throws -> [DayOverride]
    nonisolated func fetchOverrides(dayKeys: [String]) throws -> [DayOverride]
    nonisolated func fetchLocations(from start: Date, to end: Date) throws -> [LocationSample]
    nonisolated func fetchPhotos(from start: Date, to end: Date) throws -> [PhotoSignal]
    nonisolated func fetchCalendarSignals(from start: Date, to end: Date) throws -> [CalendarSignal]

    nonisolated func fetchEarliestStayDate() throws -> Date?
    nonisolated func fetchEarliestOverrideDate() throws -> Date?
    nonisolated func fetchEarliestLocationDate() throws -> Date?
    nonisolated func fetchEarliestPhotoDate() throws -> Date?
    nonisolated func fetchEarliestCalendarSignalDate() throws -> Date?
    nonisolated func fetchEarliestPresenceDayDate() throws -> Date?

    nonisolated func fetchPresenceDays(keys: [String]) throws -> [PresenceDay]
    nonisolated func fetchPresenceDayKeys(from start: Date, to end: Date) throws -> Set<String>
    nonisolated func fetchPresenceDayKeys(in keys: Set<String>) throws -> Set<String>
    nonisolated func fetchNearestKnownPresenceDay(before date: Date) throws -> PresenceDay?
    nonisolated func fetchNearestKnownPresenceDay(after date: Date) throws -> PresenceDay?
    nonisolated func insertPresenceDay(_ day: PresenceDay)
    nonisolated func deletePresenceDays(afterDayKey dayKey: String) throws

    nonisolated func save() throws
}

struct RealLedgerDataFetcher: LedgerDataFetching {
    let modelContext: ModelContext

    func fetchStays(from start: Date, to end: Date) throws -> [Stay] {
        let distantFuture = Date.distantFuture
        let descriptor = FetchDescriptor<Stay>(
            predicate: #Predicate { stay in
                stay.enteredOn <= end && (stay.exitedOn ?? distantFuture) >= start
            }
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchOverrides(from start: Date, to end: Date) throws -> [DayOverride] {
        let descriptor = FetchDescriptor<DayOverride>(
            predicate: #Predicate { override in
                override.date >= start && override.date <= end
            }
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchOverrides(dayKeys: [String]) throws -> [DayOverride] {
        let descriptor = FetchDescriptor<DayOverride>(
            predicate: #Predicate { override in
                dayKeys.contains(override.dayKey)
            }
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchLocations(from start: Date, to end: Date) throws -> [LocationSample] {
        let descriptor = FetchDescriptor<LocationSample>(
            predicate: #Predicate { sample in
                sample.timestamp >= start && sample.timestamp <= end
            }
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchPhotos(from start: Date, to end: Date) throws -> [PhotoSignal] {
        let descriptor = FetchDescriptor<PhotoSignal>(
            predicate: #Predicate { signal in
                signal.timestamp >= start && signal.timestamp <= end
            }
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchCalendarSignals(from start: Date, to end: Date) throws -> [CalendarSignal] {
        let descriptor = FetchDescriptor<CalendarSignal>(
            predicate: #Predicate { signal in
                signal.timestamp >= start && signal.timestamp <= end
            }
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchEarliestStayDate() throws -> Date? {
        var descriptor = FetchDescriptor<Stay>(sortBy: [SortDescriptor(\.enteredOn, order: .forward)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.enteredOn
    }

    func fetchEarliestOverrideDate() throws -> Date? {
        var descriptor = FetchDescriptor<DayOverride>(sortBy: [SortDescriptor(\.date, order: .forward)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.date
    }

    func fetchEarliestLocationDate() throws -> Date? {
        var descriptor = FetchDescriptor<LocationSample>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.timestamp
    }

    func fetchEarliestPhotoDate() throws -> Date? {
        var descriptor = FetchDescriptor<PhotoSignal>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.timestamp
    }

    func fetchEarliestCalendarSignalDate() throws -> Date? {
        var descriptor = FetchDescriptor<CalendarSignal>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.timestamp
    }

    func fetchEarliestPresenceDayDate() throws -> Date? {
        var descriptor = FetchDescriptor<PresenceDay>(sortBy: [SortDescriptor(\.date, order: .forward)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.date
    }

    func fetchPresenceDays(keys: [String]) throws -> [PresenceDay] {
        let descriptor = FetchDescriptor<PresenceDay>(
            predicate: #Predicate { keys.contains($0.dayKey) }
        )
        return try modelContext.fetch(descriptor)
    }

    // Optimization: Fetch only keys within the relevant date range to avoid loading the entire history.
    func fetchPresenceDayKeys(from start: Date, to end: Date) throws -> Set<String> {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else { return [] }

        let timeZone = calendar.timeZone
        var day = startDay
        var keys: Set<String> = []
        while day <= endDay {
            keys.insert(DayKey.make(from: day, timeZone: timeZone))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return try fetchPresenceDayKeys(in: keys)
    }

    func fetchPresenceDayKeys(in keys: Set<String>) throws -> Set<String> {
        guard !keys.isEmpty else { return [] }
        let lookup = Array(keys)
        let descriptor = FetchDescriptor<PresenceDay>(
            predicate: #Predicate { day in
                lookup.contains(day.dayKey)
            }
        )
        let days = try modelContext.fetch(descriptor)
        // ⚡ Bolt: Use .lazy.map to avoid O(N) intermediate array allocation when initializing a Set.
        return Set(days.lazy.map { $0.dayKey })
    }

    func fetchNearestKnownPresenceDay(before date: Date) throws -> PresenceDay? {
        let descriptor = FetchDescriptor<PresenceDay>(
            predicate: #Predicate { day in
                day.date < date
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try fetchFirstKnownPresenceDay(matching: descriptor)
    }

    func fetchNearestKnownPresenceDay(after date: Date) throws -> PresenceDay? {
        let descriptor = FetchDescriptor<PresenceDay>(
            predicate: #Predicate { day in
                day.date > date
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try fetchFirstKnownPresenceDay(matching: descriptor)
    }

    private func fetchFirstKnownPresenceDay(
        matching baseDescriptor: FetchDescriptor<PresenceDay>
    ) throws -> PresenceDay? {
        // Country identity is derived from the persisted allocation array, so it can't be
        // expressed as a SwiftData predicate. Page date-sorted candidates and filter locally.
        let batchSize = 64
        var descriptor = baseDescriptor
        var offset = 0

        while true {
            descriptor.fetchLimit = batchSize
            descriptor.fetchOffset = offset

            let days = try modelContext.fetch(descriptor)
            if let knownDay = days.first(where: { !$0.countryAllocations.isEmpty }) {
                return knownDay
            }
            guard days.count == batchSize else { return nil }
            offset += days.count
        }
    }

    func insertPresenceDay(_ day: PresenceDay) {
        modelContext.insert(day)
    }

    func deletePresenceDays(afterDayKey dayKey: String) throws {
        let days = try modelContext.fetch(FetchDescriptor<PresenceDay>())
        for day in days where day.dayKey > dayKey {
            modelContext.delete(day)
        }
    }

    func save() throws {
        try modelContext.save()
    }
}
