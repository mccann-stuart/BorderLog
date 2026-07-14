import XCTest
@testable import Learn

final class CountryDayCountingModeTests: XCTestCase {

    func testIdReturnsRawValue() {
        XCTAssertEqual(CountryDayCountingMode.resolvedCountry.id, "resolvedCountry")
        XCTAssertEqual(CountryDayCountingMode.doubleCountDays.id, "doubleCountDays")
    }

    func testLabelReturnsCorrectString() {
        XCTAssertEqual(CountryDayCountingMode.resolvedCountry.label, "Resolved Country")
        XCTAssertEqual(CountryDayCountingMode.doubleCountDays.label, "Double Count Days")
    }

    func testStoredModeReturnsCorrectModeForValidStrings() {
        XCTAssertEqual(CountryDayCountingMode.storedMode(from: "resolvedCountry"), .resolvedCountry)
        XCTAssertEqual(CountryDayCountingMode.storedMode(from: "doubleCountDays"), .doubleCountDays)
    }

    func testStoredModeReturnsDefaultModeForInvalidOrNilStrings() {
        XCTAssertEqual(CountryDayCountingMode.storedMode(from: "invalid"), .resolvedCountry)
        XCTAssertEqual(CountryDayCountingMode.storedMode(from: nil), .resolvedCountry)
        XCTAssertEqual(CountryDayCountingMode.storedMode(from: ""), .resolvedCountry)
    }

    func testLoadFromDefaultsReturnsCorrectMode() {
        // Setup a temporary UserDefaults instance
        let suiteName = "test_CountryDayCountingMode"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create temporary UserDefaults")
            return
        }

        // Clean up before and after tests
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Test when nothing is stored
        XCTAssertEqual(CountryDayCountingMode.load(from: defaults), .resolvedCountry)

        // Test when resolvedCountry is stored
        defaults.set("resolvedCountry", forKey: CountryDayCountingMode.storageKey)
        XCTAssertEqual(CountryDayCountingMode.load(from: defaults), .resolvedCountry)

        // Test when doubleCountDays is stored
        defaults.set("doubleCountDays", forKey: CountryDayCountingMode.storageKey)
        XCTAssertEqual(CountryDayCountingMode.load(from: defaults), .doubleCountDays)

        // Test when an invalid string is stored
        defaults.set("invalidMode", forKey: CountryDayCountingMode.storageKey)
        XCTAssertEqual(CountryDayCountingMode.load(from: defaults), .resolvedCountry)
    }
}
