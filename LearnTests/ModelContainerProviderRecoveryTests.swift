import XCTest
@testable import Learn

final class ModelContainerProviderRecoveryTests: XCTestCase {
    private struct StubError: Error, CustomStringConvertible {
        let description: String
    }

    func testRecoveryHeuristicsAreNonDestructiveByDefault() {
        let migrationError = StubError(description: "Migration failed due to incompatible schema")
        let randomError = StubError(description: "Permission denied")

        XCTAssertTrue(ModelContainerProvider.shouldAttemptRecovery(for: migrationError))
        XCTAssertFalse(ModelContainerProvider.shouldDeleteAfterRecoveryFailure(for: migrationError))
        XCTAssertFalse(ModelContainerProvider.shouldAttemptRecovery(for: randomError))
    }

    func testDeleteHeuristicRequiresCorruptionIndicators() {
        let corruptionError = StubError(description: "SQLite error: database disk image is malformed")
        let nonCorruptionError = StubError(description: "schema version mismatch")

        XCTAssertTrue(ModelContainerProvider.shouldDeleteAfterRecoveryFailure(for: corruptionError))
        XCTAssertFalse(ModelContainerProvider.shouldDeleteAfterRecoveryFailure(for: nonCorruptionError))
    }

    func testQuarantineStoreFilesMovesMainAndSidecars() throws {
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent("ModelContainerProviderRecoveryTests-\(UUID().uuidString)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: directory) }

        let storeName = "BorderLog.store"
        let sources = ["", "-wal", "-shm"].map { directory.appendingPathComponent(storeName + $0) }
        for url in sources {
            try Data("x".utf8).write(to: url)
        }

        let moved = ModelContainerProvider.quarantineStoreFiles(in: directory, named: storeName, quarantineTag: "testtag")
        XCTAssertTrue(moved)

        for url in sources {
            XCTAssertFalse(fm.fileExists(atPath: url.path))
            let quarantined = directory.appendingPathComponent(url.lastPathComponent + ".quarantine-testtag")
            XCTAssertTrue(fm.fileExists(atPath: quarantined.path))
        }
    }
}
