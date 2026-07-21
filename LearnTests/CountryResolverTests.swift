import XCTest
@testable import Learn

final class CountryResolverTests: XCTestCase {

    func testCountryResolutionCache_SetAndGetValue() async {
        let cache = CountryResolutionCache()

        let resolution = CountryResolution(
            countryCode: "GB",
            countryName: "United Kingdom",
            timeZone: TimeZone(identifier: "Europe/London")
        )

        // Initial state should be nil
        let initialValue = await cache.value(for: "GB")
        XCTAssertNil(initialValue)

        // Set value
        await cache.set(resolution, for: "GB")

        // Retrieve value
        let retrievedValue = await cache.value(for: "GB")
        XCTAssertEqual(retrievedValue?.countryCode, "GB")
        XCTAssertEqual(retrievedValue?.countryName, "United Kingdom")
        XCTAssertEqual(retrievedValue?.timeZone, TimeZone(identifier: "Europe/London"))
    }

    func testCountryResolutionCache_Overwrite() async {
        let cache = CountryResolutionCache()

        let initialResolution = CountryResolution(
            countryCode: "GB",
            countryName: "United Kingdom",
            timeZone: TimeZone(identifier: "Europe/London")
        )

        let updatedResolution = CountryResolution(
            countryCode: "UK",
            countryName: "United Kingdom of Great Britain and Northern Ireland",
            timeZone: TimeZone(identifier: "Europe/London")
        )

        await cache.set(initialResolution, for: "GB")
        await cache.set(updatedResolution, for: "GB")

        let retrievedValue = await cache.value(for: "GB")
        XCTAssertEqual(retrievedValue?.countryCode, "UK")
        XCTAssertEqual(retrievedValue?.countryName, "United Kingdom of Great Britain and Northern Ireland")
    }

    func testCountryResolutionCache_IndependentKeys() async {
        let cache = CountryResolutionCache()

        let resolution1 = CountryResolution(
            countryCode: "GB",
            countryName: "United Kingdom",
            timeZone: TimeZone(identifier: "Europe/London")
        )

        let resolution2 = CountryResolution(
            countryCode: "FR",
            countryName: "France",
            timeZone: TimeZone(identifier: "Europe/Paris")
        )

        await cache.set(resolution1, for: "key1")
        await cache.set(resolution2, for: "key2")

        let retrieved1 = await cache.value(for: "key1")
        let retrieved2 = await cache.value(for: "key2")
        let retrievedEmpty = await cache.value(for: "key3")

        XCTAssertEqual(retrieved1?.countryCode, "GB")
        XCTAssertEqual(retrieved2?.countryCode, "FR")
        XCTAssertNil(retrievedEmpty)
    }
}
