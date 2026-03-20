//
//  CalendarTabDataService.swift
//  Learn
//
//  Created by Codex on 19/03/2026.
//

import Foundation
import SwiftData

enum CalendarCountrySummaryRange: String, CaseIterable, Identifiable {
    case visibleMonth = "Visible Month"
    case last12Months = "Last 12 Months"
    case lastYear = "Last Year"
    case thisYear = "This Year"
    case last6Months = "Last 6 Months"
    case twoYearsPrior = "Two Years Prior"

    var id: Self { self }

    nonisolated func dateRange(
        visibleMonthStart: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Range<Date>? {
        switch self {
        case .visibleMonth:
            let start = calendar.startOfDay(for: visibleMonthStart)
            guard let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
            return start..<end
        case .last12Months:
            guard let start = calendar.date(byAdding: .month, value: -12, to: now) else { return nil }
            return start..<Date.distantFuture
        case .last6Months:
            guard let start = calendar.date(byAdding: .month, value: -6, to: now) else { return nil }
            return start..<Date.distantFuture
        case .thisYear:
            guard let start = calendar.date(from: calendar.dateComponents([.year], from: now)) else { return nil }
            return start..<Date.distantFuture
        case .lastYear:
            guard let startOfThisYear = calendar.date(from: calendar.dateComponents([.year], from: now)),
                  let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfThisYear) else {
                return nil
            }
            return startOfLastYear..<startOfThisYear
        case .twoYearsPrior:
            guard let startOfThisYear = calendar.date(from: calendar.dateComponents([.year], from: now)),
                  let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfThisYear),
                  let startOfTwoYearsAgo = calendar.date(byAdding: .year, value: -2, to: startOfThisYear) else {
                return nil
            }
            return startOfTwoYearsAgo..<startOfLastYear
        }
    }

    nonisolated func contains(
        dayKey: String,
        visibleMonthStart: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let range = dateRange(visibleMonthStart: visibleMonthStart, now: now, calendar: calendar) else {
            return false
        }
        guard let dayDate = DayKey.date(for: dayKey, timeZone: calendar.timeZone) else {
            return false
        }
        return range.contains(dayDate)
    }
}

struct CalendarDayCountry: Hashable, Sendable {
    let id: String
    let countryName: String
    let countryCode: String?
    let regionRaw: String
}

struct CalendarDaySummary: Identifiable, Sendable {
    let dayKey: String
    let date: Date
    let dayNumber: Int
    let countries: [CalendarDayCountry]
    let hasFlight: Bool
    let isToday: Bool
    let isInCurrentMonth: Bool

    var id: String { dayKey }
}

struct CalendarCountryDaysSummary: Identifiable, Sendable {
    let id: String
    let countryName: String
    let countryCode: String?
    let totalDays: Int
    let regionRaw: String
    let maxAllowedDays: Int?
}

struct CalendarTabSnapshot: Sendable {
    let visibleMonthStart: Date
    let daySummaries: [CalendarDaySummary]
    let countrySummaries: [CalendarCountryDaysSummary]
    let earliestAvailableMonth: Date
    let latestAvailableMonth: Date

    static func placeholder(
        visibleMonthStart: Date,
        latestAvailableMonth: Date? = nil,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> CalendarTabSnapshot {
        let normalizedMonthStart = CalendarTabDataService.monthStart(for: visibleMonthStart, calendar: calendar)
        let latestMonth = latestAvailableMonth ?? CalendarTabDataService.monthStart(for: now, calendar: calendar)
        let daySummaries = CalendarTabDataService.makeMonthDaySummaries(
            for: normalizedMonthStart,
            accumulators: [:],
            calendar: calendar,
            now: now
        )
        return CalendarTabSnapshot(
            visibleMonthStart: normalizedMonthStart,
            daySummaries: daySummaries,
            countrySummaries: [],
            earliestAvailableMonth: normalizedMonthStart,
            latestAvailableMonth: latestMonth
        )
    }
}

@ModelActor
actor CalendarTabDataService {
    fileprivate struct DayAccumulator {
        var countriesByID: [String: CalendarDayCountry] = [:]
        var hasFlight = false
    }

    fileprivate struct DayKeyRange {
        let start: Date
        let end: Date
        let dayKeys: [String]
        let dayKeySet: Set<String>
    }

    func snapshot(
        visibleMonthStart: Date,
        summaryRange: CalendarCountrySummaryRange,
        now: Date = Date()
    ) throws -> CalendarTabSnapshot {
        let calendar = Calendar.current
        let normalizedVisibleMonth = Self.monthStart(for: visibleMonthStart, calendar: calendar)
        let visibleMonthRange = Self.makeMonthRange(for: normalizedVisibleMonth, calendar: calendar)
        let summaryDayRange = Self.makeSummaryRange(
            for: summaryRange,
            visibleMonthStart: normalizedVisibleMonth,
            now: now,
            calendar: calendar
        )

        let fetchDayKeys = Array(visibleMonthRange.dayKeySet.union(summaryDayRange.dayKeySet)).sorted()
        let fetchDayKeySet = Set(fetchDayKeys)
        let rangeStartKey = fetchDayKeys.first
        let rangeEndKey = fetchDayKeys.last

        let overrides = try fetchOverrides(dayKeys: fetchDayKeys)
        let locations = try fetchLocations(dayKeys: fetchDayKeys)
        let photos = try fetchPhotos(dayKeys: fetchDayKeys)
        let calendarSignals = try fetchCalendarSignals(dayKeys: fetchDayKeys)
        let presenceDays = try fetchPresenceDays(dayKeys: fetchDayKeys)
        let stays = try fetchStays(rangeStartKey: rangeStartKey, rangeEndKey: rangeEndKey)
        let countryConfigs = try modelContext.fetch(FetchDescriptor<CountryConfig>())

        var accumulators = Dictionary(uniqueKeysWithValues: fetchDayKeys.map { ($0, DayAccumulator()) })

        for override in overrides {
            addCountry(
                to: &accumulators,
                dayKey: override.dayKey,
                countryCode: override.countryCode,
                countryName: override.countryName
            )
        }

        for location in locations {
            addCountry(
                to: &accumulators,
                dayKey: location.dayKey,
                countryCode: location.countryCode,
                countryName: location.countryName
            )
        }

        for photo in photos {
            addCountry(
                to: &accumulators,
                dayKey: photo.dayKey,
                countryCode: photo.countryCode,
                countryName: photo.countryName
            )
        }

        for signal in calendarSignals {
            addCountry(
                to: &accumulators,
                dayKey: signal.dayKey,
                countryCode: signal.countryCode,
                countryName: signal.countryName
            )
            accumulators[signal.dayKey, default: DayAccumulator()].hasFlight = true
        }

        if let rangeStartKey, let rangeEndKey {
            for stay in stays {
                addStay(
                    stay,
                    to: &accumulators,
                    allowedDayKeys: fetchDayKeySet,
                    rangeStartKey: rangeStartKey,
                    rangeEndKey: rangeEndKey
                )
            }
        }

        let configByID = Dictionary(countryConfigs.map { ($0.countryCode, $0.maxAllowedDays) }, uniquingKeysWith: { current, _ in current })
        let daySummaries = Self.makeMonthDaySummaries(
            for: normalizedVisibleMonth,
            accumulators: accumulators,
            calendar: calendar,
            now: now
        )
        let countrySummaries = makeCountrySummaries(
            from: accumulators,
            presenceDays: presenceDays,
            summaryDayKeys: summaryDayRange.dayKeys,
            summaryRange: summaryRange,
            visibleMonthStart: normalizedVisibleMonth,
            configByID: configByID,
            now: now,
            calendar: calendar
        )

        let earliestMonth = try fetchEarliestAvailableMonth(fallback: normalizedVisibleMonth, calendar: calendar)
        let latestMonth = Self.monthStart(for: now, calendar: calendar)

        return CalendarTabSnapshot(
            visibleMonthStart: normalizedVisibleMonth,
            daySummaries: daySummaries,
            countrySummaries: countrySummaries,
            earliestAvailableMonth: earliestMonth,
            latestAvailableMonth: latestMonth
        )
    }

    private func fetchOverrides(dayKeys: [String]) throws -> [DayOverride] {
        guard !dayKeys.isEmpty else { return [] }
        let descriptor = FetchDescriptor<DayOverride>(
            predicate: #Predicate { override in
                dayKeys.contains(override.dayKey)
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchLocations(dayKeys: [String]) throws -> [LocationSample] {
        guard !dayKeys.isEmpty else { return [] }
        let descriptor = FetchDescriptor<LocationSample>(
            predicate: #Predicate { sample in
                dayKeys.contains(sample.dayKey)
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchPhotos(dayKeys: [String]) throws -> [PhotoSignal] {
        guard !dayKeys.isEmpty else { return [] }
        let descriptor = FetchDescriptor<PhotoSignal>(
            predicate: #Predicate { signal in
                dayKeys.contains(signal.dayKey)
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchCalendarSignals(dayKeys: [String]) throws -> [CalendarSignal] {
        guard !dayKeys.isEmpty else { return [] }
        let descriptor = FetchDescriptor<CalendarSignal>(
            predicate: #Predicate { signal in
                dayKeys.contains(signal.dayKey)
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchPresenceDays(dayKeys: [String]) throws -> [PresenceDay] {
        guard !dayKeys.isEmpty else { return [] }
        let descriptor = FetchDescriptor<PresenceDay>(
            predicate: #Predicate { day in
                dayKeys.contains(day.dayKey)
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchStays(rangeStartKey: String?, rangeEndKey: String?) throws -> [Stay] {
        guard let rangeStartKey, let rangeEndKey else { return [] }
        let descriptor = FetchDescriptor<Stay>(
            predicate: #Predicate { stay in
                stay.entryDayKey <= rangeEndKey && (stay.exitDayKey ?? rangeEndKey) >= rangeStartKey
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchEarliestAvailableMonth(
        fallback: Date,
        calendar: Calendar
    ) throws -> Date {
        let earliestKeys = try [
            fetchEarliestStayKey(),
            fetchEarliestOverrideKey(),
            fetchEarliestLocationKey(),
            fetchEarliestPhotoKey(),
            fetchEarliestCalendarSignalKey()
        ].compactMap { $0 }

        guard let earliestKey = earliestKeys.min(),
              let earliestDate = DayKey.date(for: earliestKey, timeZone: calendar.timeZone) else {
            return fallback
        }

        return Self.monthStart(for: earliestDate, calendar: calendar)
    }

    private func fetchEarliestStayKey() throws -> String? {
        var descriptor = FetchDescriptor<Stay>(sortBy: [SortDescriptor(\.entryDayKey, order: .forward)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.entryDayKey
    }

    private func fetchEarliestOverrideKey() throws -> String? {
        var descriptor = FetchDescriptor<DayOverride>(sortBy: [SortDescriptor(\.dayKey, order: .forward)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.dayKey
    }

    private func fetchEarliestLocationKey() throws -> String? {
        var descriptor = FetchDescriptor<LocationSample>(sortBy: [SortDescriptor(\.dayKey, order: .forward)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.dayKey
    }

    private func fetchEarliestPhotoKey() throws -> String? {
        var descriptor = FetchDescriptor<PhotoSignal>(sortBy: [SortDescriptor(\.dayKey, order: .forward)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.dayKey
    }

    private func fetchEarliestCalendarSignalKey() throws -> String? {
        var descriptor = FetchDescriptor<CalendarSignal>(sortBy: [SortDescriptor(\.dayKey, order: .forward)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.dayKey
    }

    private func addCountry(
        to accumulators: inout [String: DayAccumulator],
        dayKey: String,
        countryCode: String?,
        countryName: String?
    ) {
        guard var accumulator = accumulators[dayKey],
              let country = normalizedCountry(countryCode: countryCode, countryName: countryName) else {
            return
        }
        accumulator.countriesByID[country.id] = country
        accumulators[dayKey] = accumulator
    }

    private func addStay(
        _ stay: Stay,
        to accumulators: inout [String: DayAccumulator],
        allowedDayKeys: Set<String>,
        rangeStartKey: String,
        rangeEndKey: String
    ) {
        let clampedStartKey = max(stay.entryDayKey, rangeStartKey)
        let exitKey = min(stay.exitDayKey ?? rangeEndKey, rangeEndKey)
        guard clampedStartKey <= exitKey else { return }

        let stayTimeZone = DayIdentity.canonicalTimeZone(
            preferredTimeZoneId: stay.dayTimeZoneId,
            fallback: .current
        )
        guard let startDate = DayKey.date(for: clampedStartKey, timeZone: stayTimeZone),
              let endDate = DayKey.date(for: exitKey, timeZone: stayTimeZone) else {
            return
        }

        var stayCalendar = Calendar(identifier: .gregorian)
        stayCalendar.timeZone = stayTimeZone

        var day = startDate
        while day <= endDate {
            let dayKey = DayKey.make(from: day, timeZone: stayTimeZone)
            if allowedDayKeys.contains(dayKey) {
                addCountry(
                    to: &accumulators,
                    dayKey: dayKey,
                    countryCode: stay.countryCode,
                    countryName: stay.countryName
                )
            }
            guard let next = stayCalendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
    }

    private func normalizedCountry(
        countryCode: String?,
        countryName: String?
    ) -> CalendarDayCountry? {
        let normalizedCode = CountryCodeNormalizer.normalize(countryCode)
        let trimmedName = countryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard normalizedCode != nil || !trimmedName.isEmpty else { return nil }

        let resolvedName: String
        if !trimmedName.isEmpty {
            resolvedName = trimmedName
        } else if let normalizedCode {
            resolvedName = Locale.current.localizedString(forRegionCode: normalizedCode) ?? normalizedCode
        } else {
            return nil
        }

        let identity = normalizedCode ?? resolvedName
        let regionRaw: String
        if let normalizedCode {
            regionRaw = SchengenMembers.isMember(normalizedCode) ? Region.schengen.rawValue : Region.nonSchengen.rawValue
        } else {
            regionRaw = Region.other.rawValue
        }

        return CalendarDayCountry(
            id: identity,
            countryName: resolvedName,
            countryCode: normalizedCode,
            regionRaw: regionRaw
        )
    }

    private func makeCountrySummaries(
        from accumulators: [String: DayAccumulator],
        presenceDays: [PresenceDay],
        summaryDayKeys: [String],
        summaryRange: CalendarCountrySummaryRange,
        visibleMonthStart: Date,
        configByID: [String: Int?],
        now: Date,
        calendar: Calendar
    ) -> [CalendarCountryDaysSummary] {
        var counts: [String: (country: CalendarDayCountry, totalDays: Int)] = [:]
        let resolvedDayMap = Dictionary(uniqueKeysWithValues: presenceDays.map { ($0.dayKey, $0) })

        for dayKey in summaryDayKeys {
            guard summaryRange.contains(dayKey: dayKey, visibleMonthStart: visibleMonthStart, now: now, calendar: calendar) else {
                continue
            }

            if let resolvedDay = resolvedDayMap[dayKey] {
                guard let country = normalizedCountry(
                    countryCode: resolvedDay.countryCode,
                    countryName: resolvedDay.countryName
                ) else {
                    continue
                }
                let current = counts[country.id] ?? (country, 0)
                counts[country.id] = (country: current.country, totalDays: current.totalDays + 1)
                continue
            }

            guard let accumulator = accumulators[dayKey] else { continue }
            for country in accumulator.countriesByID.values {
                let current = counts[country.id] ?? (country, 0)
                counts[country.id] = (country: current.country, totalDays: current.totalDays + 1)
            }
        }

        return counts.values
            .map { entry in
                CalendarCountryDaysSummary(
                    id: entry.country.id,
                    countryName: entry.country.countryName,
                    countryCode: entry.country.countryCode,
                    totalDays: entry.totalDays,
                    regionRaw: entry.country.regionRaw,
                    maxAllowedDays: configByID[entry.country.id] ?? nil
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalDays == rhs.totalDays {
                    return lhs.countryName.localizedCaseInsensitiveCompare(rhs.countryName) == .orderedAscending
                }
                return lhs.totalDays > rhs.totalDays
            }
    }

    nonisolated fileprivate static func monthStart(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    nonisolated fileprivate static func makeMonthRange(for visibleMonthStart: Date, calendar: Calendar) -> DayKeyRange {
        let normalizedStart = Self.monthStart(for: visibleMonthStart, calendar: calendar)
        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: normalizedStart),
              let finalDay = calendar.date(byAdding: .day, value: -1, to: monthEnd) else {
            let key = DayKey.make(from: normalizedStart, timeZone: calendar.timeZone)
            return DayKeyRange(start: normalizedStart, end: normalizedStart, dayKeys: [key], dayKeySet: [key])
        }
        return makeRange(from: normalizedStart, to: finalDay, calendar: calendar)
    }

    nonisolated fileprivate static func makeSummaryRange(
        for summaryRange: CalendarCountrySummaryRange,
        visibleMonthStart: Date,
        now: Date,
        calendar: Calendar
    ) -> DayKeyRange {
        guard let dateRange = summaryRange.dateRange(
            visibleMonthStart: visibleMonthStart,
            now: now,
            calendar: calendar
        ) else {
            return makeMonthRange(for: visibleMonthStart, calendar: calendar)
        }

        let start = calendar.startOfDay(for: dateRange.lowerBound)
        let endBase: Date
        if dateRange.upperBound == Date.distantFuture {
            endBase = now
        } else {
            endBase = calendar.date(byAdding: .second, value: -1, to: dateRange.upperBound) ?? dateRange.lowerBound
        }
        let end = max(start, calendar.startOfDay(for: endBase))
        return makeRange(from: start, to: end, calendar: calendar)
    }

    nonisolated fileprivate static func makeRange(from start: Date, to end: Date, calendar: Calendar) -> DayKeyRange {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else {
            let startKey = DayKey.make(from: startDay, timeZone: calendar.timeZone)
            return DayKeyRange(start: startDay, end: startDay, dayKeys: [startKey], dayKeySet: [startKey])
        }

        var day = startDay
        var dayKeys: [String] = []
        while day <= endDay {
            dayKeys.append(DayKey.make(from: day, timeZone: calendar.timeZone))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return DayKeyRange(start: startDay, end: endDay, dayKeys: dayKeys, dayKeySet: Set(dayKeys))
    }

    nonisolated fileprivate static func makeMonthDaySummaries(
        for visibleMonthStart: Date,
        accumulators: [String: DayAccumulator],
        calendar: Calendar,
        now: Date
    ) -> [CalendarDaySummary] {
        let monthRange = makeMonthRange(for: visibleMonthStart, calendar: calendar)
        let todayKey = DayKey.make(from: now, timeZone: calendar.timeZone)

        return monthRange.dayKeys.compactMap { dayKey in
            guard let date = DayKey.date(for: dayKey, timeZone: calendar.timeZone) else { return nil }
            let countries = accumulators[dayKey]?.countriesByID.values.sorted { lhs, rhs in
                lhs.countryName.localizedCaseInsensitiveCompare(rhs.countryName) == .orderedAscending
            } ?? []
            return CalendarDaySummary(
                dayKey: dayKey,
                date: date,
                dayNumber: calendar.component(.day, from: date),
                countries: countries,
                hasFlight: accumulators[dayKey]?.hasFlight ?? false,
                isToday: dayKey == todayKey,
                isInCurrentMonth: true
            )
        }
    }
}
