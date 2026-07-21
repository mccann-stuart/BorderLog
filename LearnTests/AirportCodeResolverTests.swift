#if canImport(XCTest)
import XCTest
import Foundation
@testable import Learn

final class AirportCodeResolverTests: XCTestCase {

    func testResolveKnownAirport() async throws {
        let resolver = AirportCodeResolver()

        // JFK: 40.639447,-73.779317,US
        let resolved = await resolver.resolve(code: "JFK")
        XCTAssertNotNil(resolved)
        guard let location = resolved else { return }

        XCTAssertEqual(location.country, "US")
        XCTAssertEqual(location.lat, 40.639447, accuracy: 0.000001)
        XCTAssertEqual(location.lon, -73.779317, accuracy: 0.000001)
    }

    func testResolveCaseInsensitive() async throws {
        let resolver = AirportCodeResolver()

        // lhr (LHR): 51.4706,-0.461941,GB
        let resolved = await resolver.resolve(code: "lhr")
        XCTAssertNotNil(resolved)
        guard let location = resolved else { return }

        XCTAssertEqual(location.country, "GB")
        XCTAssertEqual(location.lat, 51.4706, accuracy: 0.000001)
        XCTAssertEqual(location.lon, -0.461941, accuracy: 0.000001)
    }

    func testResolveNonExistentAirport() async {
        let resolver = AirportCodeResolver()

        let location = await resolver.resolve(code: "XYZ999")

        XCTAssertNil(location)
    }

    func testResolveAnotherKnownAirport() async throws {
        let resolver = AirportCodeResolver()

        // DXB: 25.2527999878,55.3643989563,AE
        let resolved = await resolver.resolve(code: "DXB")
        XCTAssertNotNil(resolved)
        guard let location = resolved else { return }

        XCTAssertEqual(location.country, "AE")
        XCTAssertEqual(location.lat, 25.2527999878, accuracy: 0.000001)
        XCTAssertEqual(location.lon, 55.3643989563, accuracy: 0.000001)
    }

    func testResolveEmptyString() async {
        let resolver = AirportCodeResolver()

        let location = await resolver.resolve(code: "")
        XCTAssertNil(location)
    }

    func testConcurrentResolves() async throws {
        let resolver = AirportCodeResolver()

        let results = await withTaskGroup(of: AirportLocation?.self) { group in
            group.addTask { await resolver.resolve(code: "JFK") }
            group.addTask { await resolver.resolve(code: "LHR") }
            group.addTask { await resolver.resolve(code: "DXB") }
            group.addTask { await resolver.resolve(code: "XYZ999") }

            var collected: [AirportLocation?] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        XCTAssertEqual(results.count, 4)
        XCTAssertEqual(results.compactMap { $0 }.count, 3)
    }
}
#endif
