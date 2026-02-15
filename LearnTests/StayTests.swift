import XCTest
import Foundation
import SwiftData
@testable import Learn
final class StayTests: XCTestCase {
    func testDisplayTitleFormatting() {
        let entryWithCode = Stay(
            countryName: "France",
            countryCode: "fr",
            enteredOn: Date()
        )
        XCTAssertTrue(entryWithCode.displayTitle == "France (FR)")

        let entryWithEmptyCode = Stay(
            countryName: "France",
            countryCode: "",
            enteredOn: Date()
        )
        XCTAssertTrue(entryWithEmptyCode.displayTitle == "France")

        let entryWithWhitespaceCode = Stay(
            countryName: "France",
            countryCode: "  ",
            enteredOn: Date()
        )
        XCTAssertTrue(entryWithWhitespaceCode.displayTitle == "France")

        let entryWithNilCode = Stay(
            countryName: "France",
            countryCode: nil,
            enteredOn: Date()
        )
        XCTAssertTrue(entryWithNilCode.displayTitle == "France")

        let entryWithMixedCaseCode = Stay(
            countryName: "France",
            countryCode: "fR",
            enteredOn: Date()
        )
        XCTAssertTrue(entryWithMixedCaseCode.displayTitle == "France (FR)")
    }
}
