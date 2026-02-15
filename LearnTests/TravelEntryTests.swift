//
//  TravelEntryTests.swift
//  LearnTests
//
//  Created by Mccann Stuart on 15/02/2026.
//

import Testing
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

struct TravelEntryTests {
    @Test func displayTitleFormattedCorrectly() {
        let entryWithCode = MockTravelEntry(countryName: "France", countryCode: "fr")
        #expect(entryWithCode.displayTitle == "France (FR)")

        let entryWithEmptyCode = MockTravelEntry(countryName: "France", countryCode: "")
        #expect(entryWithEmptyCode.displayTitle == "France")

        let entryWithWhitespaceCode = MockTravelEntry(countryName: "France", countryCode: "  ")
        #expect(entryWithWhitespaceCode.displayTitle == "France")

        let entryWithNilCode = MockTravelEntry(countryName: "France", countryCode: nil)
        #expect(entryWithNilCode.displayTitle == "France")

        let entryWithMixedCaseCode = MockTravelEntry(countryName: "France", countryCode: "fR")
        #expect(entryWithMixedCaseCode.displayTitle == "France (FR)")
    }

    @Test func regionGetterAndSetter() {
        let entry = MockTravelEntry(countryName: "France", region: .schengen)

        #expect(entry.region == .schengen)
        #expect(entry.regionRaw == "Schengen")

        entry.region = .nonSchengen
        #expect(entry.region == .nonSchengen)
        #expect(entry.regionRaw == "Non-Schengen")

        entry.region = .other
        #expect(entry.region == .other)
        #expect(entry.regionRaw == "Other")
    }

    @Test func regionHandlesInvalidRawValue() {
        let entry = MockTravelEntry(countryName: "France", region: .schengen)
        entry.regionRaw = "Invalid"
        #expect(entry.region == .other)
    }
}
