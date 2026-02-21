//
//  LearnTests.swift
//  LearnTests
//
//  Created by Mccann Stuart on 13/02/2026.
//

import XCTest
@testable import Learn
@MainActor
final class SchengenCalculatorWindowTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testCountsUniqueDaysAcrossOverlappingStays() async throws {
        // Stays are typically provided in reverse chronological order (descending by enteredOn) via @Query.
        // We simulate this order here to match the optimized logic in SchengenCalculator.
        let stays = [
            Stay(countryName: "Spain", region: .schengen, enteredOn: date(2026, 2, 4), exitedOn: date(2026, 2, 6)),
            Stay(countryName: "France", region: .schengen, enteredOn: date(2026, 2, 1), exitedOn: date(2026, 2, 5)),
        ]

        let summary = SchengenCalculator.summary(
            for: stays,
            overrides: [DayOverride](),
            asOf: date(2026, 2, 15),
            calendar: calendar
        )

        let usedDays = summary.usedDays
        let remainingDays = summary.remainingDays
        let overstayDays = summary.overstayDays
        XCTAssertEqual(usedDays, 6)
        XCTAssertEqual(remainingDays, 84)
        XCTAssertEqual(overstayDays, 0)
    }

    func testOverridesRemoveSchengenDays() async throws {
        let stays = [
            Stay(countryName: "Germany", region: .schengen, enteredOn: date(2026, 2, 1), exitedOn: date(2026, 2, 3)),
        ]
        let overrides = [
            DayOverride(date: date(2026, 2, 2), countryName: "United Kingdom", region: .nonSchengen, notes: "Transit"),
        ]

        let summary = SchengenCalculator.summary(
            for: stays,
            overrides: overrides,
            asOf: date(2026, 2, 10),
            calendar: calendar
        )

        let usedDays = summary.usedDays
        let remainingDays = summary.remainingDays
        XCTAssertEqual(usedDays, 2)
        XCTAssertEqual(remainingDays, 88)
    }

    func testOverridesAddSchengenDays() async throws {
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

        let usedDays = summary.usedDays
        let remainingDays = summary.remainingDays
        XCTAssertEqual(usedDays, 2)
        XCTAssertEqual(remainingDays, 88)
    }

    func testIgnoresStaysCompletelyBeforeWindow() async throws {
        let referenceDate = date(2026, 7, 1) // window starts 2026-01-03
        let stays = [
            Stay(countryName: "France", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 2)),
        ]

        let summary = SchengenCalculator.summary(
            for: stays,
            overrides: [DayOverride](),
            asOf: referenceDate,
            calendar: calendar
        )

        let usedDays = summary.usedDays
        XCTAssertEqual(usedDays, 0)
    }

    func testClampsStaysPartiallyBeforeWindow() async throws {
        let referenceDate = date(2026, 7, 1) // window starts 2026-01-03
        let stays = [
            Stay(countryName: "France", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5)),
        ]

        let summary = SchengenCalculator.summary(
            for: stays,
            overrides: [DayOverride](),
            asOf: referenceDate,
            calendar: calendar
        )

        // Should count Jan 3, 4, 5
        let usedDays = summary.usedDays
        XCTAssertEqual(usedDays, 3)
    }

    func testIgnoresStaysCompletelyAfterWindow() async throws {
        let referenceDate = date(2026, 7, 1)
        let stays = [
            Stay(countryName: "France", region: .schengen, enteredOn: date(2026, 7, 2), exitedOn: date(2026, 7, 10)),
        ]

        let summary = SchengenCalculator.summary(
            for: stays,
            overrides: [DayOverride](),
            asOf: referenceDate,
            calendar: calendar
        )

        let usedDays = summary.usedDays
        XCTAssertEqual(usedDays, 0)
    }

    func testClampsStaysPartiallyAfterWindow() async throws {
        let referenceDate = date(2026, 7, 1)
        let stays = [
            Stay(countryName: "France", region: .schengen, enteredOn: date(2026, 6, 30), exitedOn: date(2026, 7, 5)),
        ]

        let summary = SchengenCalculator.summary(
            for: stays,
            overrides: [DayOverride](),
            asOf: referenceDate,
            calendar: calendar
        )

        // Should count June 30, July 1
        let usedDays = summary.usedDays
        XCTAssertEqual(usedDays, 2)
    }

    func testHandleEmptyStaysList() async throws {
        let stays: [Stay] = []
        let overrides: [DayOverride] = []

        let summary = SchengenCalculator.summary(
            for: stays,
            overrides: overrides,
            asOf: date(2026, 2, 15),
            calendar: calendar
        )

        let usedDays = summary.usedDays
        let remainingDays = summary.remainingDays
        let overstayDays = summary.overstayDays
        XCTAssertEqual(usedDays, 0)
        XCTAssertEqual(remainingDays, 90)
        XCTAssertEqual(overstayDays, 0)
    }
}
