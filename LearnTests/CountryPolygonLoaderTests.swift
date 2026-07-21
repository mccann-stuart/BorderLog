import Foundation
import XCTest
import zlib

@testable import Learn

final class CountryPolygonLoaderTests: XCTestCase {
    func testDecompressZlibRejectsEmptyData() {
        XCTAssertThrowsError(try Data().decompressZlib()) { error in
            let error = error as NSError
            XCTAssertEqual(error.domain, "Zlib")
            XCTAssertEqual(error.code, Int(Z_DATA_ERROR))
        }
    }

    func testDecompressZlibDecodesBundledCountryPolygons() throws {
        let compressed = try XCTUnwrap(
            Data(base64Encoded: CountryPolygonsData.base64CompressedGeoJSON)
        )

        let decompressed = try compressed.decompressZlib()
        let json = try JSONSerialization.jsonObject(with: decompressed)

        XCTAssertFalse(decompressed.isEmpty)
        XCTAssertNotNil(json as? [String: Any])
    }
}
