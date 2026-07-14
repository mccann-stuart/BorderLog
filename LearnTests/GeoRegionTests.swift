import XCTest
@testable import Learn

final class GeoRegionTests: XCTestCase {

    func testRegionForKnownCodes() {
        XCTAssertEqual(GeoRegion.region(for: "US"), .northAmerica)
        XCTAssertEqual(GeoRegion.region(for: "CA"), .northAmerica)

        XCTAssertEqual(GeoRegion.region(for: "GT"), .centralAmerica)
        XCTAssertEqual(GeoRegion.region(for: "PA"), .centralAmerica)

        XCTAssertEqual(GeoRegion.region(for: "CU"), .caribbean)
        XCTAssertEqual(GeoRegion.region(for: "PR"), .caribbean)

        XCTAssertEqual(GeoRegion.region(for: "BR"), .southAmerica)
        XCTAssertEqual(GeoRegion.region(for: "AR"), .southAmerica)

        XCTAssertEqual(GeoRegion.region(for: "GB"), .europe)
        XCTAssertEqual(GeoRegion.region(for: "FR"), .europe)

        XCTAssertEqual(GeoRegion.region(for: "NG"), .africa)
        XCTAssertEqual(GeoRegion.region(for: "ZA"), .africa)

        XCTAssertEqual(GeoRegion.region(for: "IL"), .middleEast)
        XCTAssertEqual(GeoRegion.region(for: "AE"), .middleEast)

        XCTAssertEqual(GeoRegion.region(for: "JP"), .asia)
        XCTAssertEqual(GeoRegion.region(for: "IN"), .asia)

        XCTAssertEqual(GeoRegion.region(for: "AU"), .oceania)
        XCTAssertEqual(GeoRegion.region(for: "NZ"), .oceania)
    }

    func testRegionForWhitespaceAndCaseInsensitivity() {
        XCTAssertEqual(GeoRegion.region(for: "us"), .northAmerica)
        XCTAssertEqual(GeoRegion.region(for: " US "), .northAmerica)
        XCTAssertEqual(GeoRegion.region(for: "  ca  "), .northAmerica)
        XCTAssertEqual(GeoRegion.region(for: "gt\n"), .centralAmerica)
        XCTAssertEqual(GeoRegion.region(for: "\tGB\t"), .europe)
    }

    func testRegionForUnknownCodesFallback() {
        // Obscure or invalid codes should fallback to .europe
        XCTAssertEqual(GeoRegion.region(for: "XX"), .europe)
        XCTAssertEqual(GeoRegion.region(for: "INVALID"), .europe)
        XCTAssertEqual(GeoRegion.region(for: ""), .europe)
        XCTAssertEqual(GeoRegion.region(for: "   "), .europe)
        XCTAssertEqual(GeoRegion.region(for: "123"), .europe)
    }

    func testCountryCodesProperty() {
        let northAmericaCodes = GeoRegion.northAmerica.countryCodes
        XCTAssertTrue(northAmericaCodes.contains("US"))
        XCTAssertTrue(northAmericaCodes.contains("CA"))
        XCTAssertTrue(northAmericaCodes.contains("MX"))
        XCTAssertEqual(northAmericaCodes.count, 3)

        let centralAmericaCodes = GeoRegion.centralAmerica.countryCodes
        XCTAssertTrue(centralAmericaCodes.contains("GT"))
        XCTAssertTrue(centralAmericaCodes.contains("PA"))

        let europeCodes = GeoRegion.europe.countryCodes
        XCTAssertTrue(europeCodes.contains("GB"))
        XCTAssertTrue(europeCodes.contains("FR"))
    }
}
