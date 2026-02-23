//
//  LedgerDataFetching.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import SwiftData

protocol LedgerDataFetching {
    func fetchStays(from start: Date, to end: Date) throws -> [Stay]
    func fetchOverrides(from start: Date, to end: Date) throws -> [DayOverride]
    func fetchLocations(from start: Date, to end: Date) throws -> [LocationSample]
    func fetchPhotos(from start: Date, to end: Date) throws -> [PhotoSignal]

    func fetchEarliestStayDate() throws -> Date?
    func fetchEarliestOverrideDate() throws -> Date?
    func fetchEarliestLocationDate() throws -> Date?
    func fetchEarliestPhotoDate() throws -> Date?

    func fetchPresenceDays(keys: [String]) throws -> [PresenceDay]
    func fetchAllPresenceDayKeys() throws -> Set<String>
    func insertPresenceDay(_ day: PresenceDay)

    func save() throws
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

    func fetchPresenceDays(keys: [String]) throws -> [PresenceDay] {
        let descriptor = FetchDescriptor<PresenceDay>(
            predicate: #Predicate { keys.contains($0.dayKey) }
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchAllPresenceDayKeys() throws -> Set<String> {
        let descriptor = FetchDescriptor<PresenceDay>()
        let days = try modelContext.fetch(descriptor)
        return Set(days.map { $0.dayKey })
    }

    func insertPresenceDay(_ day: PresenceDay) {
        modelContext.insert(day)
    }

    func save() throws {
        try modelContext.save()
    }
}
