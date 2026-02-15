//
//  DayOverrideTests.swift
//  LearnTests
//
//  Created by Jules on 16/02/2026.
//

import XCTest
import Foundation
@testable import Learn
final class DayOverrideTests: XCTestCase {

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testDisplayTitle_withNilCountryCode_returnsCountryName() {
        let override = DayOverride(
            date: date(2026, 1, 1),
            countryName: "France",
            countryCode: nil
        )

        XCTAssertTrue(override.displayTitle == "France")
    }

    func testDisplayTitle_withEmptyCountryCode_returnsCountryName() {
        let override = DayOverride(
            date: date(2026, 1, 1),
            countryName: "Spain",
            countryCode: ""
        )

        XCTAssertTrue(override.displayTitle == "Spain")
    }

    func testDisplayTitle_withWhitespaceCountryCode_returnsCountryName() {
        let override = DayOverride(
            date: date(2026, 1, 1),
            countryName: "Italy",
            countryCode: "   "
        )

        XCTAssertTrue(override.displayTitle == "Italy")
    }

    func testDisplayTitle_withValidCountryCode_returnsFormattedTitle() {
        let override = DayOverride(
            date: date(2026, 1, 1),
            countryName: "Germany",
            countryCode: "DE"
        )

        XCTAssertTrue(override.displayTitle == "Germany (DE)")
    }

    func testDisplayTitle_withLowercaseCountryCode_returnsUppercasedCodeInTitle() {
        let override = DayOverride(
            date: date(2026, 1, 1),
            countryName: "Portugal",
            countryCode: "pt"
        )

        XCTAssertTrue(override.displayTitle == "Portugal (PT)")
    }

    func testDisplayTitle_withWhitespaceAroundCode_trimsAndFormats() {
         let override = DayOverride(
             date: date(2026, 1, 1),
             countryName: "Belgium",
             countryCode: " be "
         )

         XCTAssertTrue(override.displayTitle == "Belgium (BE)")
     }
}
