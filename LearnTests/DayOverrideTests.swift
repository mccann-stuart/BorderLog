//
//  DayOverrideTests.swift
//  LearnTests
//
//  Created by Jules on 16/02/2026.
//

import XCTest
import Foundation
@testable import Learn
@MainActor
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

        let title = override.displayTitle
        XCTAssertEqual(title, "France")
    }

    func testDisplayTitle_withEmptyCountryCode_returnsCountryName() {
        let override = DayOverride(
            date: date(2026, 1, 1),
            countryName: "Spain",
            countryCode: ""
        )

        let title = override.displayTitle
        XCTAssertEqual(title, "Spain")
    }

    func testDisplayTitle_withWhitespaceCountryCode_returnsCountryName() {
        let override = DayOverride(
            date: date(2026, 1, 1),
            countryName: "Italy",
            countryCode: "   "
        )

        let title = override.displayTitle
        XCTAssertEqual(title, "Italy")
    }

    func testDisplayTitle_withValidCountryCode_returnsFormattedTitle() {
        let override = DayOverride(
            date: date(2026, 1, 1),
            countryName: "Germany",
            countryCode: "DE"
        )

        let title = override.displayTitle
        XCTAssertEqual(title, "Germany (DE)")
    }

    func testDisplayTitle_withLowercaseCountryCode_returnsUppercasedCodeInTitle() {
        let override = DayOverride(
            date: date(2026, 1, 1),
            countryName: "Portugal",
            countryCode: "pt"
        )

        let title = override.displayTitle
        XCTAssertEqual(title, "Portugal (PT)")
    }

    func testDisplayTitle_withWhitespaceAroundCode_trimsAndFormats() {
         let override = DayOverride(
             date: date(2026, 1, 1),
             countryName: "Belgium",
             countryCode: " be "
         )

         let title = override.displayTitle
         XCTAssertEqual(title, "Belgium (BE)")
     }
}
