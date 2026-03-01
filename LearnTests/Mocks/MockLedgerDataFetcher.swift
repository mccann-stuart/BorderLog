//
//  MockLedgerDataFetcher.swift
//  LearnTests
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import SwiftData
@testable import Learn

class MockLedgerDataFetcher: LedgerDataFetching {
    var stays: [Stay] = []
    var overrides: [DayOverride] = []
    var locations: [LocationSample] = []
    var photos: [PhotoSignal] = []
    var calendarSignals: [CalendarSignal] = []

    var earliestStayDate: Date?
    var earliestOverrideDate: Date?
    var earliestLocationDate: Date?
    var earliestPhotoDate: Date?
    var earliestCalendarSignalDate: Date?

    var presenceDays: [String: PresenceDay] = [:]

    var fetchStaysError: Error?
    var fetchOverridesError: Error?
    var fetchLocationsError: Error?
    var fetchPhotosError: Error?
    var fetchCalendarSignalsError: Error?
    var fetchPresenceDaysError: Error?
    var fetchPresenceDayKeysError: Error?
    var saveError: Error?

    var saveCalled = false
    var insertPresenceDayCalled = false
    var insertedPresenceDayKeys: [String] = []

    func fetchStays(from start: Date, to end: Date) throws -> [Stay] {
        if let error = fetchStaysError { throw error }
        return stays
    }

    func fetchOverrides(from start: Date, to end: Date) throws -> [DayOverride] {
        if let error = fetchOverridesError { throw error }
        return overrides
    }

    func fetchLocations(from start: Date, to end: Date) throws -> [LocationSample] {
        if let error = fetchLocationsError { throw error }
        return locations
    }

    func fetchPhotos(from start: Date, to end: Date) throws -> [PhotoSignal] {
        if let error = fetchPhotosError { throw error }
        return photos
    }

    func fetchCalendarSignals(from start: Date, to end: Date) throws -> [CalendarSignal] {
        if let error = fetchCalendarSignalsError { throw error }
        return calendarSignals
    }

    func fetchEarliestStayDate() throws -> Date? {
        return earliestStayDate
    }

    func fetchEarliestOverrideDate() throws -> Date? {
        return earliestOverrideDate
    }

    func fetchEarliestLocationDate() throws -> Date? {
        return earliestLocationDate
    }

    func fetchEarliestPhotoDate() throws -> Date? {
        return earliestPhotoDate
    }

    func fetchEarliestCalendarSignalDate() throws -> Date? {
        return earliestCalendarSignalDate
    }

    func fetchPresenceDays(keys: [String]) throws -> [PresenceDay] {
        if let error = fetchPresenceDaysError { throw error }
        return keys.compactMap { presenceDays[$0] }
    }

    func fetchPresenceDayKeys(from start: Date, to end: Date) throws -> Set<String> {
        if let error = fetchPresenceDayKeysError { throw error }
        let keys = presenceDays.values.filter { $0.date >= start && $0.date <= end }.map { $0.dayKey }
        return Set(keys)
    }

    func fetchNearestKnownPresenceDay(before date: Date) throws -> PresenceDay? {
        presenceDays.values
            .filter { day in
                day.date < date && (day.countryCode != nil || day.countryName != nil)
            }
            .max(by: { $0.date < $1.date })
    }

    func fetchNearestKnownPresenceDay(after date: Date) throws -> PresenceDay? {
        presenceDays.values
            .filter { day in
                day.date > date && (day.countryCode != nil || day.countryName != nil)
            }
            .min(by: { $0.date < $1.date })
    }

    func insertPresenceDay(_ day: PresenceDay) {
        insertPresenceDayCalled = true
        insertedPresenceDayKeys.append(day.dayKey)
        presenceDays[day.dayKey] = day
    }

    func save() throws {
        saveCalled = true
        if let error = saveError { throw error }
    }
}
