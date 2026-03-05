#if canImport(XCTest)
import XCTest
import Foundation
@testable import Learn

final class AirportCodeResolverTests: XCTestCase {

    func testResolveKnownAirport() async throws {
        let resolver = AirportCodeResolver.shared

        // JFK: 40.639447,-73.779317,US
        let location = try XCTUnwrap(await resolver.resolve(code: "JFK"))

        XCTAssertEqual(location.country, "US")
        XCTAssertEqual(location.lat, 40.639447, accuracy: 0.000001)
        XCTAssertEqual(location.lon, -73.779317, accuracy: 0.000001)
    }

    func testResolveCaseInsensitive() async throws {
        let resolver = AirportCodeResolver.shared

        // lhr (LHR): 51.4706,-0.461941,GB
        let location = try XCTUnwrap(await resolver.resolve(code: "lhr"))

        XCTAssertEqual(location.country, "GB")
        XCTAssertEqual(location.lat, 51.4706, accuracy: 0.000001)
        XCTAssertEqual(location.lon, -0.461941, accuracy: 0.000001)
    }

    func testResolveNonExistentAirport() async {
        let resolver = AirportCodeResolver.shared

        let location = await resolver.resolve(code: "XYZ999")

        XCTAssertNil(location)
    }

    func testResolveAnotherKnownAirport() async throws {
        let resolver = AirportCodeResolver.shared

        // DXB: 25.2527999878,55.3643989563,AE
        let location = try XCTUnwrap(await resolver.resolve(code: "DXB"))

        XCTAssertEqual(location.country, "AE")
        XCTAssertEqual(location.lat, 25.2527999878, accuracy: 0.000001)
        XCTAssertEqual(location.lon, 55.3643989563, accuracy: 0.000001)
    }
}
#endif
