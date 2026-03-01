import XCTest
import SwiftData
import CoreLocation
@testable import Learn

private struct StubResolver: CountryResolving {
    func resolveCountry(for location: CLLocation) async -> CountryResolution? {
        CountryResolution(countryCode: "GB", countryName: "United Kingdom", timeZone: TimeZone(secondsFromGMT: 0))
    }
}

final class PhotoSignalIngestorCoreTests: XCTestCase {
    private enum ForcedSaveError: Error {
        case failed
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: PhotoSignal.self, PhotoIngestState.self, configurations: config)
    }

    func testFetchExistingAssetIdHashesReturnsPrefetchedSet() async throws {
        let container = try makeContainer()
        let ingestor = PhotoSignalIngestor(modelContainer: container, resolver: StubResolver())

        let calendar = Calendar(identifier: .gregorian)
        let d1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let d2 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let d3 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!

        await ingestor.addTestSignal(assetIdHash: "hash-1", timestamp: d1)
        await ingestor.addTestSignal(assetIdHash: "hash-2", timestamp: d2)
        await ingestor.addTestSignal(assetIdHash: "hash-3", timestamp: d3)
        try await ingestor.saveContextIfNeeded()

        let config = PhotoSignalIngestor.IngestQueryConfig(startDate: d1, endDate: d2, sortAscending: true)
        let hashes = try await ingestor.fetchExistingAssetIdHashes(config: config)

        XCTAssertEqual(hashes, Set(["hash-1", "hash-2"]))
    }

    func testSaveContextIfNeededThrowsWhenSaveOverrideFails() async throws {
        let container = try makeContainer()
        let ingestor = PhotoSignalIngestor(modelContainer: container, resolver: StubResolver())

        await ingestor.addTestSignal(assetIdHash: "hash-fail")
        await ingestor.setSaveOverride {
            throw ForcedSaveError.failed
        }

        await XCTAssertThrowsErrorAsync {
            try await ingestor.saveContextIfNeeded()
        }
    }
}

private extension XCTestCase {
    func XCTAssertThrowsErrorAsync(
        _ expression: @escaping () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
            XCTFail("Expected error to be thrown", file: file, line: line)
        } catch {
            // Expected.
        }
    }
}
