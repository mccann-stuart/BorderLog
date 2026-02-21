import XCTest
import Foundation
import SwiftData
@testable import Learn
@MainActor
final class StayTests: XCTestCase {
    func testDisplayTitleFormatting() {
        let entryWithCode = Stay(
            countryName: "France",
            countryCode: "fr",
            enteredOn: Date()
        )
        let codeTitle = entryWithCode.displayTitle
        XCTAssertEqual(codeTitle, "France (FR)")

        let entryWithEmptyCode = Stay(
            countryName: "France",
            countryCode: "",
            enteredOn: Date()
        )
        let emptyTitle = entryWithEmptyCode.displayTitle
        XCTAssertEqual(emptyTitle, "France")

        let entryWithWhitespaceCode = Stay(
            countryName: "France",
            countryCode: "  ",
            enteredOn: Date()
        )
        let whitespaceTitle = entryWithWhitespaceCode.displayTitle
        XCTAssertEqual(whitespaceTitle, "France")

        let entryWithNilCode = Stay(
            countryName: "France",
            countryCode: nil,
            enteredOn: Date()
        )
        let nilTitle = entryWithNilCode.displayTitle
        XCTAssertEqual(nilTitle, "France")

        let entryWithMixedCaseCode = Stay(
            countryName: "France",
            countryCode: "fR",
            enteredOn: Date()
        )
        let mixedTitle = entryWithMixedCaseCode.displayTitle
        XCTAssertEqual(mixedTitle, "France (FR)")
    }
}
