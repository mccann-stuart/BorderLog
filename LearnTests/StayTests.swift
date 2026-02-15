import Testing
import Foundation
import SwiftData
@testable import Learn

struct StayTests {
    @Test func displayTitleFormatting() {
        let entryWithCode = Stay(
            countryName: "France",
            countryCode: "fr",
            enteredOn: Date()
        )
        #expect(entryWithCode.displayTitle == "France (FR)")

        let entryWithEmptyCode = Stay(
            countryName: "France",
            countryCode: "",
            enteredOn: Date()
        )
        #expect(entryWithEmptyCode.displayTitle == "France")

        let entryWithWhitespaceCode = Stay(
            countryName: "France",
            countryCode: "  ",
            enteredOn: Date()
        )
        #expect(entryWithWhitespaceCode.displayTitle == "France")

        let entryWithNilCode = Stay(
            countryName: "France",
            countryCode: nil,
            enteredOn: Date()
        )
        #expect(entryWithNilCode.displayTitle == "France")

        let entryWithMixedCaseCode = Stay(
            countryName: "France",
            countryCode: "fR",
            enteredOn: Date()
        )
        #expect(entryWithMixedCaseCode.displayTitle == "France (FR)")
    }
}
