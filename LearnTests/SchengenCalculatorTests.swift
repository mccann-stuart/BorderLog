#if canImport(XCTest)
import XCTest
import Foundation
@testable import Learn
@MainActor
final class SchengenCalculatorTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return cal
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        return calendar.date(from: comps)!
    }

    func testEmptyData_hasZeroUsedAndFullRemaining() {
        let stays: [Stay] = []
        let overrides: [DayOverride] = []
        let ref = day(2026, 2, 15)
        let summary = SchengenCalculator.summary(for: stays, overrides: overrides, asOf: ref, calendar: calendar)
        let usedDays = summary.usedDays
        let remainingDays = summary.remainingDays
        let overstayDays = summary.overstayDays
        XCTAssertEqual(usedDays, 0)
        XCTAssertEqual(remainingDays, 90)
        XCTAssertEqual(overstayDays, 0)
    }

    func testExactly90DaysUsed_inWindow() {
        // One continuous Schengen stay of 90 days ending on ref
        let ref = day(2026, 2, 15)
        let start = calendar.date(byAdding: .day, value: -89, to: ref)!
        let stay = Stay(countryName: "Spain", countryCode: "ES", region: .schengen, enteredOn: start, exitedOn: ref)
        let summary = SchengenCalculator.summary(for: [stay], overrides: [DayOverride](), asOf: ref, calendar: calendar)
        let usedDays = summary.usedDays
        let remainingDays = summary.remainingDays
        let overstayDays = summary.overstayDays
        XCTAssertEqual(usedDays, 90)
        XCTAssertEqual(remainingDays, 0)
        XCTAssertEqual(overstayDays, 0)
    }

    func testOverstay_whenMoreThan90Days() {
        let ref = day(2026, 2, 15)
        let start = calendar.date(byAdding: .day, value: -100, to: ref)!
        let stay = Stay(countryName: "Italy", countryCode: "IT", region: .schengen, enteredOn: start, exitedOn: ref)
        let summary = SchengenCalculator.summary(for: [stay], overrides: [DayOverride](), asOf: ref, calendar: calendar)
        let usedDays = summary.usedDays
        let remainingDays = summary.remainingDays
        let overstayDays = summary.overstayDays
        XCTAssertEqual(usedDays, 101) // inclusive of start and end
        XCTAssertEqual(overstayDays, 11)
        XCTAssertEqual(remainingDays, 0)
    }

    func testNonSchengen_stay_doesNotCount() {
        let ref = day(2026, 2, 15)
        let start = calendar.date(byAdding: .day, value: -30, to: ref)!
        let stay = Stay(countryName: "United Kingdom", countryCode: "GB", region: .nonSchengen, enteredOn: start, exitedOn: ref)
        let summary = SchengenCalculator.summary(for: [stay], overrides: [DayOverride](), asOf: ref, calendar: calendar)
        let usedDays = summary.usedDays
        let remainingDays = summary.remainingDays
        let overstayDays = summary.overstayDays
        XCTAssertEqual(usedDays, 0)
        XCTAssertEqual(remainingDays, 90)
        XCTAssertEqual(overstayDays, 0)
    }

    func testOverrides_addAndRemoveDays() {
        let ref = day(2026, 2, 15)
        // 10 days Schengen stay
        let start = calendar.date(byAdding: .day, value: -9, to: ref)!
        let stay = Stay(countryName: "Portugal", countryCode: "PT", region: .schengen, enteredOn: start, exitedOn: ref)

        // One override moves a day to non-Schengen (removes 1)
        let removeDay = DayOverride(date: calendar.date(byAdding: .day, value: -5, to: ref)!, countryName: "United Kingdom", countryCode: "GB", region: .nonSchengen)
        // One override adds a Schengen day outside the stay
        let addDay = DayOverride(date: calendar.date(byAdding: .day, value: -20, to: ref)!, countryName: "France", countryCode: "FR", region: .schengen)

        let summary = SchengenCalculator.summary(for: [stay], overrides: [removeDay, addDay], asOf: ref, calendar: calendar)
        // Base used = 10, minus 1 (removed), plus 1 (added) => 10
        let usedDays = summary.usedDays
        let remainingDays = summary.remainingDays
        let overstayDays = summary.overstayDays
        XCTAssertEqual(usedDays, 10)
        XCTAssertEqual(remainingDays, 80)
        XCTAssertEqual(overstayDays, 0)
    }

    func testComplexOverlaps_handlesNestedAndAdjacentStays() {
        let ref = day(2026, 2, 15)
        // Overlap scenario:
        // Stay A: Jan 1 - Jan 10 (10 days)
        // Stay B: Jan 2 - Jan 5 (Nested in A)
        // Stay C: Jan 5 - Jan 15 (Overlaps A, extends to 15)
        // Stay D: Jan 16 - Jan 20 (Adjacent to C)
        // Expected merged interval: Jan 1 - Jan 20 (20 days total)

        let stayA = StayInfo(enteredOn: day(2026, 1, 1), exitedOn: day(2026, 1, 10), region: .schengen)
        let stayB = StayInfo(enteredOn: day(2026, 1, 2), exitedOn: day(2026, 1, 5), region: .schengen)
        let stayC = StayInfo(enteredOn: day(2026, 1, 5), exitedOn: day(2026, 1, 15), region: .schengen)
        let stayD = StayInfo(enteredOn: day(2026, 1, 16), exitedOn: day(2026, 1, 20), region: .schengen)

        // Must be sorted descending by enteredOn
        let stays = [stayD, stayC, stayB, stayA]

        let summary = SchengenCalculator.summary(for: stays, overrides: [], asOf: ref, calendar: calendar)

        XCTAssertEqual(summary.usedDays, 20)
        XCTAssertEqual(summary.remainingDays, 70)
    }

    func testWindowBoundaries_clipsStaysCorrectly() {
        // Reference Date: July 1, 2026 (Day 182)
        // Window Start: Jan 3, 2026 (Day 3) -> 182 - 179 = 3
        let ref = day(2026, 7, 1)

        // Stay: Jan 1 - Jan 10
        // Should be clipped to Jan 3 - Jan 10 (8 days)
        let stay = StayInfo(enteredOn: day(2026, 1, 1), exitedOn: day(2026, 1, 10), region: .schengen)

        let summary = SchengenCalculator.summary(for: [stay], overrides: [], asOf: ref, calendar: calendar)

        XCTAssertEqual(summary.usedDays, 8)
    }

    func testFutureStays_areIgnored() {
        let ref = day(2026, 1, 1)
        // Stay starts Jan 2
        let stay = StayInfo(enteredOn: day(2026, 1, 2), exitedOn: day(2026, 1, 5), region: .schengen)

        let summary = SchengenCalculator.summary(for: [stay], overrides: [], asOf: ref, calendar: calendar)

        XCTAssertEqual(summary.usedDays, 0)
    }

    func testOpenEndedStay_countsUntilReferenceDate() {
        let ref = day(2026, 1, 10)
        // Stay starts Jan 1, open ended
        let stay = StayInfo(enteredOn: day(2026, 1, 1), exitedOn: nil, region: .schengen)

        let summary = SchengenCalculator.summary(for: [stay], overrides: [], asOf: ref, calendar: calendar)

        // Should count Jan 1 to Jan 10 -> 10 days
        XCTAssertEqual(summary.usedDays, 10)
    }
}
#endif
