import XCTest
import SwiftData
import CoreLocation
@testable import Learn

private struct StubResolver: CountryResolving {
    func resolveCountry(for location: CLLocation) async -> CountryResolution? {
        CountryResolution(countryCode: "GB", countryName: "United Kingdom", timeZone: TimeZone(secondsFromGMT: 0))
    }
}

@MainActor
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

    func testScannedCheckpointAdvancesForDuplicateNewerAsset() throws {
        let state = PhotoIngestState(lastAssetCreationDate: makeDate(2026, 1, 1), lastAssetIdHash: "already-imported")
        let newerDuplicateDate = makeDate(2026, 2, 1)

        PhotoSignalIngestor.applyScannedAssetCheckpoint(state: state, creationDate: newerDuplicateDate)

        XCTAssertEqual(state.lastAssetCreationDate, newerDuplicateDate)
        XCTAssertEqual(state.lastAssetIdHash, "already-imported")
    }

    func testScannedCheckpointAdvancesForNonGeotaggedNewerAssetWithoutChangingImportIdentity() throws {
        let state = PhotoIngestState(lastAssetCreationDate: makeDate(2026, 1, 1), lastAssetIdHash: "last-geotagged")
        let nonGeotaggedDate = makeDate(2026, 3, 10)

        PhotoSignalIngestor.applyScannedAssetCheckpoint(state: state, creationDate: nonGeotaggedDate)

        XCTAssertEqual(state.lastAssetCreationDate, nonGeotaggedDate)
        XCTAssertEqual(state.lastAssetIdHash, "last-geotagged")
        XCTAssertNil(state.lastIngestedAt)
    }

    func testSequencedCheckpointKeepsMaxScannedDateSeparateFromImportedAsset() throws {
        let state = PhotoIngestState()
        let newestScannedDate = makeDate(2026, 4, 5)
        let olderImportedDate = makeDate(2026, 3, 20)
        let importedAt = makeDate(2026, 4, 6)

        PhotoSignalIngestor.applyScannedAssetCheckpoint(state: state, creationDate: newestScannedDate)
        PhotoSignalIngestor.applyScannedAssetCheckpoint(state: state, creationDate: olderImportedDate)
        PhotoSignalIngestor.applyImportedAssetCheckpoint(
            state: state,
            assetIdHash: "older-geotagged",
            importedAt: importedAt
        )

        XCTAssertEqual(state.lastAssetCreationDate, newestScannedDate)
        XCTAssertEqual(state.lastAssetIdHash, "older-geotagged")
        XCTAssertEqual(state.lastIngestedAt, importedAt)
    }

    func testCaptureProvenanceAcceptsDirectCameraCapture() {
        let captureDate = Date(timeIntervalSince1970: 1_700_000_000)
        let metadata = PhotoCaptureMetadata(
            exifOriginalDate: captureDate,
            exifDigitizedDate: captureDate.addingTimeInterval(1),
            hasCameraMakerNote: true
        )

        XCTAssertNil(
            PhotoSignalIngestor.captureRejectionReason(
                creationDate: captureDate.addingTimeInterval(1),
                addedDate: captureDate.addingTimeInterval(30),
                metadata: metadata
            )
        )
    }

    func testCaptureProvenanceRejectsPhotoAddedLongAfterCapture() {
        let captureDate = Date(timeIntervalSince1970: 1_700_000_000)
        let metadata = PhotoCaptureMetadata(
            exifOriginalDate: captureDate,
            exifDigitizedDate: captureDate,
            hasCameraMakerNote: true
        )

        XCTAssertEqual(
            PhotoSignalIngestor.captureRejectionReason(
                creationDate: captureDate,
                addedDate: captureDate.addingTimeInterval(
                    PhotoSignalIngestor.maximumCaptureToLibraryDelay + 1
                ),
                metadata: metadata
            ),
            .implausibleLibraryAdditionDate
        )
    }

    func testCaptureProvenanceRejectsMissingMakerNote() {
        let captureDate = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertEqual(
            PhotoSignalIngestor.captureRejectionReason(
                creationDate: captureDate,
                addedDate: captureDate,
                metadata: PhotoCaptureMetadata(
                    exifOriginalDate: captureDate,
                    exifDigitizedDate: captureDate,
                    hasCameraMakerNote: false
                )
            ),
            .missingCameraMakerNote
        )
    }

    func testCaptureProvenanceRejectsMissingTimezoneAwareEXIFDate() {
        let captureDate = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertEqual(
            PhotoSignalIngestor.captureRejectionReason(
                creationDate: captureDate,
                addedDate: captureDate,
                metadata: PhotoCaptureMetadata(
                    exifOriginalDate: nil,
                    exifDigitizedDate: captureDate,
                    hasCameraMakerNote: true
                )
            ),
            .missingTimezoneAwareEXIFDates
        )
    }

    func testCaptureProvenanceRejectsEXIFCreationDateMismatch() {
        let captureDate = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertEqual(
            PhotoSignalIngestor.captureRejectionReason(
                creationDate: captureDate.addingTimeInterval(
                    PhotoSignalIngestor.timestampTolerance + 1
                ),
                addedDate: captureDate.addingTimeInterval(30),
                metadata: PhotoCaptureMetadata(
                    exifOriginalDate: captureDate,
                    exifDigitizedDate: captureDate,
                    hasCameraMakerNote: true
                )
            ),
            .creationDateMismatch
        )
    }

    func testCaptureProvenanceAcceptsLibraryDelayBoundary() {
        let captureDate = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertNil(
            PhotoSignalIngestor.captureRejectionReason(
                creationDate: captureDate,
                addedDate: captureDate.addingTimeInterval(
                    PhotoSignalIngestor.maximumCaptureToLibraryDelay
                ),
                metadata: PhotoCaptureMetadata(
                    exifOriginalDate: captureDate,
                    exifDigitizedDate: captureDate,
                    hasCameraMakerNote: true
                )
            )
        )
    }

    func testEXIFDateParserAppliesRecordedOffset() throws {
        let date = try XCTUnwrap(
            PhotoSignalIngestor.parseEXIFDate(
                value: "2026:07:13 12:34:56",
                offset: "+02:00"
            )
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 13)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 34)
        XCTAssertEqual(components.second, 56)
    }

    func testEXIFDateParserRejectsTimestampWithoutOffset() {
        XCTAssertNil(
            PhotoSignalIngestor.parseEXIFDate(
                value: "2026:07:13 12:34:56",
                offset: nil
            )
        )
    }

    func testProvenanceRebuildDeletesExistingSignalsAndResetsCheckpoint() async throws {
        let container = try makeContainer()
        let ingestor = PhotoSignalIngestor(modelContainer: container, resolver: StubResolver())
        let firstDate = makeDate(2026, 1, 1)
        let secondDate = makeDate(2026, 1, 2)

        await ingestor.addTestSignal(assetIdHash: "old-photo-1", timestamp: firstDate)
        await ingestor.addTestSignal(assetIdHash: "old-photo-2", timestamp: secondDate)
        try await ingestor.saveContextIfNeeded()

        let removedDayKeys = try await ingestor.prepareForProvenanceRebuildForTesting()
        try await ingestor.saveContextIfNeeded()

        let context = ModelContext(container)
        let remainingSignals = try context.fetch(FetchDescriptor<PhotoSignal>())
        let states = try context.fetch(FetchDescriptor<PhotoIngestState>())

        XCTAssertEqual(
            removedDayKeys,
            Set([
                DayKey.make(from: firstDate, timeZone: .current),
                DayKey.make(from: secondDate, timeZone: .current)
            ])
        )
        XCTAssertTrue(remainingSignals.isEmpty)
        XCTAssertEqual(states.count, 1)
        XCTAssertNil(states[0].lastAssetCreationDate)
        XCTAssertFalse(states[0].fullScanCompleted)
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
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
