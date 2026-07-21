import XCTest
@testable import Learn

final class PendingLocationSnapshotTests: XCTestCase {
    func testConcurrentFileBackedEnqueuesDedupeAndPreserveUniqueSnapshots() async throws {
        let queueURL = try makeQueueDirectory()
        defer { try? FileManager.default.removeItem(at: queueURL) }
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let baseDate = Date().addingTimeInterval(-60)
        let snapshots = (0..<50).map { index in
            PendingLocationSnapshot(
                timestamp: baseDate.addingTimeInterval(TimeInterval(index)),
                latitude: 51.5 + Double(index) / 10_000,
                longitude: -0.12,
                accuracyMeters: 15,
                sourceRaw: LocationSampleSource.widget.rawValue,
                timeZoneId: "Europe/London",
                dayKey: "2026-04-27",
                countryCode: "GB",
                countryName: "United Kingdom"
            )
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for snapshot in snapshots + snapshots {
                let suiteName = suiteName
                group.addTask {
                    let taskDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
                    try PendingLocationSnapshot.enqueueThrowing(
                        snapshot,
                        in: taskDefaults,
                        queueDirectoryURL: queueURL
                    )
                }
            }
            try await group.waitForAll()
        }

        let queued = PendingLocationSnapshot.all(from: defaults, queueDirectoryURL: queueURL)
        XCTAssertEqual(Set(queued.map(\.id)), Set(snapshots.map(\.id)))
        XCTAssertEqual(queued.count, snapshots.count)
    }

    func testPendingSnapshotsRemainUntilExplicitRemoval() throws {
        let queueURL = try makeQueueDirectory()
        defer { try? FileManager.default.removeItem(at: queueURL) }
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let snapshot = PendingLocationSnapshot(
            timestamp: Date().addingTimeInterval(-60),
            latitude: 48.8566,
            longitude: 2.3522,
            accuracyMeters: 20,
            sourceRaw: LocationSampleSource.widget.rawValue,
            timeZoneId: "Europe/Paris",
            dayKey: "2026-04-27",
            countryCode: "FR",
            countryName: "France"
        )

        try PendingLocationSnapshot.enqueueThrowing(snapshot, in: defaults, queueDirectoryURL: queueURL)
        let pendingBeforeFailedSave = PendingLocationSnapshot.all(from: defaults, queueDirectoryURL: queueURL)
        XCTAssertEqual(pendingBeforeFailedSave.map(\.id), [snapshot.id])

        let pendingAfterFailedSave = PendingLocationSnapshot.all(from: defaults, queueDirectoryURL: queueURL)
        XCTAssertEqual(pendingAfterFailedSave.map(\.id), [snapshot.id])

        try PendingLocationSnapshot.remove(pendingAfterFailedSave, from: defaults, queueDirectoryURL: queueURL)
        XCTAssertTrue(PendingLocationSnapshot.all(from: defaults, queueDirectoryURL: queueURL).isEmpty)
    }



    func testPruneQueueIgnoresMissingFileError() throws {
        let queueURL = try makeQueueDirectory()
        defer { try? FileManager.default.removeItem(at: queueURL) }
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }


        class MockMissingFileManager: FileManager {
            var removeItemCallCount = 0

            override func removeItem(at URL: URL) throws {
                removeItemCallCount += 1
                throw CocoaError(.fileNoSuchFile)
            }

            override func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = nil) throws {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
            }

            override func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions = []) throws -> [URL] {
                return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
            }
        }

        let mockFileManager = MockMissingFileManager()

        // Create an expired snapshot (> 30 days old) so pruneQueue attempts to remove it
        let snapshot = PendingLocationSnapshot(
            timestamp: Date().addingTimeInterval(-60 * 60 * 24 * 31),
            latitude: 48.8566,
            longitude: 2.3522,
            accuracyMeters: 20,
            sourceRaw: LocationSampleSource.widget.rawValue,
            timeZoneId: "Europe/Paris",
            dayKey: "2026-04-27",
            countryCode: "FR",
            countryName: "France"
        )

        XCTAssertNoThrow(try PendingLocationSnapshot.enqueueThrowing(snapshot, in: defaults, fileManager: mockFileManager, queueDirectoryURL: queueURL))
        XCTAssertEqual(mockFileManager.removeItemCallCount, 1)
    }

    private func makeQueueDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PendingLocationSnapshotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "PendingLocationSnapshotTests.\(UUID().uuidString)"
        return (try XCTUnwrap(UserDefaults(suiteName: suiteName)), suiteName)
    }
}
