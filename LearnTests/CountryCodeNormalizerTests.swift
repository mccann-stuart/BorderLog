import XCTest
@testable import Learn

final class CountryCodeNormalizerTests: XCTestCase {

    func testCountryCodeToEmoji() {
        XCTAssertEqual(CountryCodeNormalizer.countryCodeToEmoji("US"), "🇺🇸")
        XCTAssertEqual(CountryCodeNormalizer.countryCodeToEmoji("us"), "🇺🇸")
        XCTAssertEqual(CountryCodeNormalizer.countryCodeToEmoji("FR"), "🇫🇷")
        XCTAssertEqual(CountryCodeNormalizer.countryCodeToEmoji("UK"), "🇬🇧")
        XCTAssertEqual(CountryCodeNormalizer.countryCodeToEmoji("uk"), "🇬🇧")
        XCTAssertEqual(CountryCodeNormalizer.countryCodeToEmoji(""), "🌍")
    }

    func testNormalize() {
        XCTAssertEqual(CountryCodeNormalizer.normalize("US"), "US")
        XCTAssertEqual(CountryCodeNormalizer.normalize("us"), "US")
        XCTAssertEqual(CountryCodeNormalizer.normalize("UK"), "GB")
        XCTAssertEqual(CountryCodeNormalizer.normalize("uk"), "GB")
        XCTAssertEqual(CountryCodeNormalizer.normalize("  fr  "), "FR")
        XCTAssertNil(CountryCodeNormalizer.normalize(nil))
        XCTAssertNil(CountryCodeNormalizer.normalize(""))
        XCTAssertNil(CountryCodeNormalizer.normalize("   "))
    }

    func testCanonicalCodeWithCountryCode() {
        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: "US", countryName: nil), "US")
        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: "us", countryName: nil), "US")
        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: "es", countryName: nil), "ES")
        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: "UK", countryName: nil), "GB")
        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: "uk", countryName: nil), "GB")
        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: "  fr  ", countryName: nil), "FR")
    }

    func testCanonicalCodeWithCountryName() {
        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: nil, countryName: "United States"), "US")
        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: nil, countryName: "United States of America"), "US")
        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: nil, countryName: "usa"), "US")
        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: nil, countryName: "u.s.a."), "US")

        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: nil, countryName: "United Kingdom"), "GB")
        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: nil, countryName: "UK"), "GB")
        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: nil, countryName: "Great Britain"), "GB")

        // Relies on Locale autoupdatingCurrent / current which usually resolves standard names
        // Note: if standard names are flaky in different locales, at least check one well-known mapping.
        // We know US/GB have explicit mappings in CountryCodeNormalizer.buildNameToCodeMap.
        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: nil, countryName: "Spain"), "ES")
    }

    func testCanonicalCodeWithCodeTakingPrecedence() {
        // If both are provided, countryCode is prioritized
        XCTAssertEqual(CountryCodeNormalizer.canonicalCode(countryCode: "FR", countryName: "Spain"), "FR")
    }

    func testCanonicalCodeWithInvalidOrNil() {
        XCTAssertNil(CountryCodeNormalizer.canonicalCode(countryCode: nil, countryName: nil))
        XCTAssertNil(CountryCodeNormalizer.canonicalCode(countryCode: "   ", countryName: "   "))
        XCTAssertNil(CountryCodeNormalizer.canonicalCode(countryCode: nil, countryName: "AtlantisTheLostCity"))
    }
}
