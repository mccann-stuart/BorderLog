//
//  StayDurationTests.swift
//  LearnTests
//
//  Created by Mccann Stuart on 15/02/2026.
//

import XCTest
import Foundation
import SwiftData
@testable import Learn
@MainActor
final class StayDurationTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testSingleDayStay() {
        let stay = Stay(
            countryName: "France",
            region: .schengen,
            enteredOn: date(2024, 1, 1),
            exitedOn: date(2024, 1, 1)
        )
        // Jan 1 to Jan 1 is 1 day
        let days = stay.durationInDays(calendar: calendar)
        XCTAssertEqual(days, 1)
    }

    func testBasicDuration() {
        let stay = Stay(
            countryName: "France",
            region: .schengen,
            enteredOn: date(2024, 1, 1),
            exitedOn: date(2024, 1, 5)
        )
        // Jan 1, 2, 3, 4, 5 -> 5 days
        let days = stay.durationInDays(calendar: calendar)
        XCTAssertEqual(days, 5)
    }

    func testCrossMonth() {
        let stay = Stay(
            countryName: "France",
            region: .schengen,
            enteredOn: date(2024, 1, 31),
            exitedOn: date(2024, 2, 1)
        )
        // Jan 31, Feb 1 -> 2 days
        let days = stay.durationInDays(calendar: calendar)
        XCTAssertEqual(days, 2)
    }

    func testCrossYear() {
        let stay = Stay(
            countryName: "France",
            region: .schengen,
            enteredOn: date(2023, 12, 31),
            exitedOn: date(2024, 1, 1)
        )
        // Dec 31, Jan 1 -> 2 days
        let days = stay.durationInDays(calendar: calendar)
        XCTAssertEqual(days, 2)
    }

    func testLeapYear() {
        let stay = Stay(
            countryName: "France",
            region: .schengen,
            enteredOn: date(2024, 2, 28),
            exitedOn: date(2024, 3, 1)
        )
        // Feb 28, Feb 29 (leap), Mar 1 -> 3 days
        let days = stay.durationInDays(calendar: calendar)
        XCTAssertEqual(days, 3)
    }

    func testNonLeapYear() {
        let stay = Stay(
            countryName: "France",
            region: .schengen,
            enteredOn: date(2023, 2, 28),
            exitedOn: date(2023, 3, 1)
        )
        // Feb 28, Mar 1 -> 2 days
        let days = stay.durationInDays(calendar: calendar)
        XCTAssertEqual(days, 2)
    }

    func testOngoingStayUsesReferenceDate() {
        let stay = Stay(
            countryName: "France",
            region: .schengen,
            enteredOn: date(2024, 6, 1),
            exitedOn: nil
        )
        let referenceDate = date(2024, 6, 5)
        // June 1, 2, 3, 4, 5 -> 5 days
        let days = stay.durationInDays(asOf: referenceDate, calendar: calendar)
        XCTAssertEqual(days, 5)
    }

    func testOngoingStayWithReferenceDateSameAsStart() {
        let stay = Stay(
            countryName: "France",
            region: .schengen,
            enteredOn: date(2024, 6, 1),
            exitedOn: nil
        )
        let referenceDate = date(2024, 6, 1)
        // June 1 -> 1 day
        let days = stay.durationInDays(asOf: referenceDate, calendar: calendar)
        XCTAssertEqual(days, 1)
    }

    func testInvalidStayReturnsZero() {
        // Exited before entered
        let stay = Stay(
            countryName: "France",
            region: .schengen,
            enteredOn: date(2024, 1, 5),
            exitedOn: date(2024, 1, 1)
        )
        let days = stay.durationInDays(calendar: calendar)
        XCTAssertEqual(days, 0)
    }

    func testDurationIgnoresTimeComponents() {
        // Late entry (23:59), early exit (00:01 next day)
        // Should treat as full days: Jan 1 and Jan 2
        let stay = Stay(
            countryName: "France",
            region: .schengen,
            enteredOn: date(2024, 1, 1, hour: 23, minute: 59),
            exitedOn: date(2024, 1, 2, hour: 0, minute: 1)
        )
        let days = stay.durationInDays(calendar: calendar)
        XCTAssertEqual(days, 2)
    }
}
