//
//  DayOverrideTests.swift
//  LearnTests
//
//  Created by Jules on 16/02/2026.
//

import Testing
import Foundation
@testable import Learn

struct DayOverrideTests {

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func displayTitle_withNilCountryCode_returnsCountryName() {
        let override = DayOverride(
            date: date(2026, 1, 1),
            countryName: "France",
            countryCode: nil
        )

        #expect(override.displayTitle == "France")
    }

    @Test func displayTitle_withEmptyCountryCode_returnsCountryName() {
        let override = DayOverride(
            date: date(2026, 1, 1),
            countryName: "Spain",
            countryCode: ""
        )

        #expect(override.displayTitle == "Spain")
    }

    @Test func displayTitle_withWhitespaceCountryCode_returnsCountryName() {
        let override = DayOverride(
            date: date(2026, 1, 1),
            countryName: "Italy",
            countryCode: "   "
        )

        #expect(override.displayTitle == "Italy")
    }

    @Test func displayTitle_withValidCountryCode_returnsFormattedTitle() {
        let override = DayOverride(
            date: date(2026, 1, 1),
            countryName: "Germany",
            countryCode: "DE"
        )

        #expect(override.displayTitle == "Germany (DE)")
    }

    @Test func displayTitle_withLowercaseCountryCode_returnsUppercasedCodeInTitle() {
        let override = DayOverride(
            date: date(2026, 1, 1),
            countryName: "Portugal",
            countryCode: "pt"
        )

        #expect(override.displayTitle == "Portugal (PT)")
    }

    @Test func displayTitle_withWhitespaceAroundCode_trimsAndFormats() {
         let override = DayOverride(
             date: date(2026, 1, 1),
             countryName: "Belgium",
             countryCode: " be "
         )

         #expect(override.displayTitle == "Belgium (BE)")
     }
}
