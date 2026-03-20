import XCTest
@testable import Learn

final class CountryResolutionTests: XCTestCase {
    private func localizedCountryName(_ code: String) -> String {
        Locale.autoupdatingCurrent.localizedString(forRegionCode: code) ?? code
    }

    func testNormalizedCanonicalizesNameOnlyCountry() {
        let spainName = localizedCountryName("ES")

        let resolution = CountryResolution.normalized(
            countryCode: nil,
            countryName: spainName,
            timeZone: nil
        )

        XCTAssertEqual(resolution?.countryCode, "ES")
        XCTAssertEqual(resolution?.countryName, spainName)
    }

    func testNormalizedKeepsNameWhenCodeCannotBeDerived() {
        let resolution = CountryResolution.normalized(
            countryCode: nil,
            countryName: "Atlantis",
            timeZone: nil
        )

        XCTAssertNil(resolution?.countryCode)
        XCTAssertEqual(resolution?.countryName, "Atlantis")
    }
}
