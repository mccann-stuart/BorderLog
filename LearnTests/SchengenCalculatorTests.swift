import XCTest
import Foundation
@testable import Learn
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
        XCTAssertTrue(summary.usedDays == 0)
        XCTAssertTrue(summary.remainingDays == 90)
        XCTAssertTrue(summary.overstayDays == 0)
    }

    func testExactly90DaysUsed_inWindow() {
        // One continuous Schengen stay of 90 days ending on ref
        let ref = day(2026, 2, 15)
        let start = calendar.date(byAdding: .day, value: -89, to: ref)!
        let stay = Stay(countryName: "Spain", countryCode: "ES", region: .schengen, enteredOn: start, exitedOn: ref)
        let summary = SchengenCalculator.summary(for: [stay], overrides: [], asOf: ref, calendar: calendar)
        XCTAssertTrue(summary.usedDays == 90)
        XCTAssertTrue(summary.remainingDays == 0)
        XCTAssertTrue(summary.overstayDays == 0)
    }

    func testOverstay_whenMoreThan90Days() {
        let ref = day(2026, 2, 15)
        let start = calendar.date(byAdding: .day, value: -100, to: ref)!
        let stay = Stay(countryName: "Italy", countryCode: "IT", region: .schengen, enteredOn: start, exitedOn: ref)
        let summary = SchengenCalculator.summary(for: [stay], overrides: [], asOf: ref, calendar: calendar)
        XCTAssertTrue(summary.usedDays == 101) // inclusive of start and end
        XCTAssertTrue(summary.overstayDays == 11)
        XCTAssertTrue(summary.remainingDays == 0)
    }

    func testNonSchengen_stay_doesNotCount() {
        let ref = day(2026, 2, 15)
        let start = calendar.date(byAdding: .day, value: -30, to: ref)!
        let stay = Stay(countryName: "United Kingdom", countryCode: "UK", region: .nonSchengen, enteredOn: start, exitedOn: ref)
        let summary = SchengenCalculator.summary(for: [stay], overrides: [], asOf: ref, calendar: calendar)
        XCTAssertTrue(summary.usedDays == 0)
        XCTAssertTrue(summary.remainingDays == 90)
        XCTAssertTrue(summary.overstayDays == 0)
    }

    func testOverrides_addAndRemoveDays() {
        let ref = day(2026, 2, 15)
        // 10 days Schengen stay
        let start = calendar.date(byAdding: .day, value: -9, to: ref)!
        let stay = Stay(countryName: "Portugal", countryCode: "PT", region: .schengen, enteredOn: start, exitedOn: ref)

        // One override moves a day to non-Schengen (removes 1)
        let removeDay = DayOverride(date: calendar.date(byAdding: .day, value: -5, to: ref)!, countryName: "UK", countryCode: "UK", region: .nonSchengen)
        // One override adds a Schengen day outside the stay
        let addDay = DayOverride(date: calendar.date(byAdding: .day, value: -20, to: ref)!, countryName: "France", countryCode: "FR", region: .schengen)

        let summary = SchengenCalculator.summary(for: [stay], overrides: [removeDay, addDay], asOf: ref, calendar: calendar)
        // Base used = 10, minus 1 (removed), plus 1 (added) => 10
        XCTAssertTrue(summary.usedDays == 10)
        XCTAssertTrue(summary.remainingDays == 80)
        XCTAssertTrue(summary.overstayDays == 0)
    }
}
