import XCTest
@testable import Learn

final class CountrySummaryComponentsTests: XCTestCase {

    // MARK: - Component struct integration tests

    func testCountryDaysInfo_EmojiFallback() {
        let info = CountryDaysInfo(
            countryName: "Atlantis",
            countryCode: nil,
            totalDays: 0,
            region: .other,
            maxAllowedDays: nil
        )
        XCTAssertEqual(info.flagEmoji, "🌍")
    }

    func testCountryDaysInfo_EmojiSuccess() {
        let info = CountryDaysInfo(
            countryName: "United States",
            countryCode: "US",
            totalDays: 1,
            region: .other,
            maxAllowedDays: nil
        )
        XCTAssertEqual(info.flagEmoji, "🇺🇸")
    }

    func testCountryDaysInfo_EmojiSuccess_Lowercase() {
        let info = CountryDaysInfo(
            countryName: "Germany",
            countryCode: "de",
            totalDays: 1,
            region: .other,
            maxAllowedDays: nil
        )
        XCTAssertEqual(info.flagEmoji, "🇩🇪")
    }

    func testCountryDaysInfo_EmojiSuccess_UK_NormalizesToGB() {
        let info = CountryDaysInfo(
            countryName: "United Kingdom",
            countryCode: "UK",
            totalDays: 1,
            region: .other,
            maxAllowedDays: nil
        )
        XCTAssertEqual(info.flagEmoji, "🇬🇧")
    }

    func testCountryDaysInfo_EmojiFallback_EmptyString() {
        let info = CountryDaysInfo(
            countryName: "",
            countryCode: "",
            totalDays: 1,
            region: .other,
            maxAllowedDays: nil
        )
        XCTAssertEqual(info.flagEmoji, "🌍")
    }
}
