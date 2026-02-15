//
//  TravelEntryTests.swift
//  LearnTests
//
//  Created by Mccann Stuart on 15/02/2026.
//

import XCTest
@testable import Learn

final class MockTravelEntry: TravelEntry {
    var countryName: String
    var countryCode: String?
    var regionRaw: String
    var notes: String

    init(
        countryName: String,
        countryCode: String? = nil,
        region: Region = .schengen,
        notes: String = ""
    ) {
        self.countryName = countryName
        self.countryCode = countryCode
        self.regionRaw = region.rawValue
        self.notes = notes
    }
}
final class TravelEntryTests: XCTestCase {
    func testDisplayTitleFormattedCorrectly() {
        let entryWithCode = MockTravelEntry(countryName: "France", countryCode: "fr")
        XCTAssertTrue(entryWithCode.displayTitle == "France (FR)")

        let entryWithEmptyCode = MockTravelEntry(countryName: "France", countryCode: "")
        XCTAssertTrue(entryWithEmptyCode.displayTitle == "France")

        let entryWithWhitespaceCode = MockTravelEntry(countryName: "France", countryCode: "  ")
        XCTAssertTrue(entryWithWhitespaceCode.displayTitle == "France")

        let entryWithNilCode = MockTravelEntry(countryName: "France", countryCode: nil)
        XCTAssertTrue(entryWithNilCode.displayTitle == "France")

        let entryWithMixedCaseCode = MockTravelEntry(countryName: "France", countryCode: "fR")
        XCTAssertTrue(entryWithMixedCaseCode.displayTitle == "France (FR)")
    }

    func testRegionGetterAndSetter() {
        let entry = MockTravelEntry(countryName: "France", region: .schengen)

        XCTAssertTrue(entry.region == .schengen)
        XCTAssertTrue(entry.regionRaw == "Schengen")

        entry.region = .nonSchengen
        XCTAssertTrue(entry.region == .nonSchengen)
        XCTAssertTrue(entry.regionRaw == "Non-Schengen")

        entry.region = .other
        XCTAssertTrue(entry.region == .other)
        XCTAssertTrue(entry.regionRaw == "Other")
    }

    func testRegionHandlesInvalidRawValue() {
        let entry = MockTravelEntry(countryName: "France", region: .schengen)
        entry.regionRaw = "Invalid"
        XCTAssertTrue(entry.region == .other)
    }
}
