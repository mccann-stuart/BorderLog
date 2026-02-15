//
//  LearnTests.swift
//  LearnTests
//
//  Created by Mccann Stuart on 13/02/2026.
//

import Testing
@testable import Learn

struct SchengenCalculatorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func countsUniqueDaysAcrossOverlappingStays() async throws {
        // Stays are typically provided in reverse chronological order (descending by enteredOn) via @Query.
        // We simulate this order here to match the optimized logic in SchengenCalculator.
        let stays = [
            Stay(countryName: "Spain", region: .schengen, enteredOn: date(2026, 2, 4), exitedOn: date(2026, 2, 6)),
            Stay(countryName: "France", region: .schengen, enteredOn: date(2026, 2, 1), exitedOn: date(2026, 2, 5)),
        ]

        let summary = SchengenCalculator.summary(for: stays, asOf: date(2026, 2, 15), calendar: calendar)

        #expect(summary.usedDays == 6)
        #expect(summary.remainingDays == 84)
        #expect(summary.overstayDays == 0)
    }

    @Test func overridesRemoveSchengenDays() async throws {
        let stays = [
            Stay(countryName: "Germany", region: .schengen, enteredOn: date(2026, 2, 1), exitedOn: date(2026, 2, 3)),
        ]
        let overrides = [
            DayOverride(date: date(2026, 2, 2), countryName: "UK", region: .nonSchengen, notes: "Transit"),
        ]

        let summary = SchengenCalculator.summary(
            for: stays,
            overrides: overrides,
            asOf: date(2026, 2, 10),
            calendar: calendar
        )

        #expect(summary.usedDays == 2)
        #expect(summary.remainingDays == 88)
    }

    @Test func overridesAddSchengenDays() async throws {
        let stays: [Stay] = []
        let overrides = [
            DayOverride(date: date(2026, 2, 4), countryName: "France", region: .schengen),
            DayOverride(date: date(2026, 2, 5), countryName: "France", region: .schengen),
        ]

        let summary = SchengenCalculator.summary(
            for: stays,
            overrides: overrides,
            asOf: date(2026, 2, 10),
            calendar: calendar
        )

        #expect(summary.usedDays == 2)
        #expect(summary.remainingDays == 88)
    }

    @Test func ignoresStaysCompletelyBeforeWindow() async throws {
        let referenceDate = date(2026, 7, 1) // window starts 2026-01-03
        let stays = [
            Stay(countryName: "France", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 2)),
        ]

        let summary = SchengenCalculator.summary(for: stays, asOf: referenceDate, calendar: calendar)

        #expect(summary.usedDays == 0)
    }

    @Test func clampsStaysPartiallyBeforeWindow() async throws {
        let referenceDate = date(2026, 7, 1) // window starts 2026-01-03
        let stays = [
            Stay(countryName: "France", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5)),
        ]

        let summary = SchengenCalculator.summary(for: stays, asOf: referenceDate, calendar: calendar)

        // Should count Jan 3, 4, 5
        #expect(summary.usedDays == 3)
    }

    @Test func ignoresStaysCompletelyAfterWindow() async throws {
        let referenceDate = date(2026, 7, 1)
        let stays = [
            Stay(countryName: "France", region: .schengen, enteredOn: date(2026, 7, 2), exitedOn: date(2026, 7, 10)),
        ]

        let summary = SchengenCalculator.summary(for: stays, asOf: referenceDate, calendar: calendar)

        #expect(summary.usedDays == 0)
    }

    @Test func clampsStaysPartiallyAfterWindow() async throws {
        let referenceDate = date(2026, 7, 1)
        let stays = [
            Stay(countryName: "France", region: .schengen, enteredOn: date(2026, 6, 30), exitedOn: date(2026, 7, 5)),
        ]

        let summary = SchengenCalculator.summary(for: stays, asOf: referenceDate, calendar: calendar)

        // Should count June 30, July 1
        #expect(summary.usedDays == 2)
    }
}
