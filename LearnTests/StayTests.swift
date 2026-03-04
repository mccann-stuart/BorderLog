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

    func testCanonicalEntryAndExitDayIdentity() {
        let utc = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc

        let entered = calendar.date(from: DateComponents(year: 2026, month: 2, day: 10, hour: 8))!
        let exited = calendar.date(from: DateComponents(year: 2026, month: 2, day: 12, hour: 20))!

        let stay = Stay(
            countryName: "France",
            countryCode: "FR",
            dayTimeZoneId: utc.identifier,
            enteredOn: entered,
            exitedOn: exited
        )

        XCTAssertEqual(stay.dayTimeZoneId, utc.identifier)
        XCTAssertEqual(stay.entryDayKey, "2026-02-10")
        XCTAssertEqual(stay.exitDayKey, "2026-02-12")
    }
}
