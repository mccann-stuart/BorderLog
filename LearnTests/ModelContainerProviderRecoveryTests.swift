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

    func testEnforceStoreEpochClearsStoresOnceAndThenNoOps() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ModelContainerProviderEpochTests-\(UUID().uuidString)")
        let appGroupDir = root.appendingPathComponent("group")
        let appSupportDir = root.appendingPathComponent("support")
        let tempDir = root.appendingPathComponent("temp")
        try fm.createDirectory(at: appGroupDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        for directory in [appGroupDir, appSupportDir] {
            for file in ["BorderLog.store", "BorderLog.store-wal", "BorderLog.store-shm"] {
                try Data("x".utf8).write(to: directory.appendingPathComponent(file))
            }
        }
        try Data("x".utf8).write(to: tempDir.appendingPathComponent("BorderLog.fallback.store"))

        let suiteName = "ModelContainerProviderEpochTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(0, forKey: ModelContainerProvider.storeEpochKeyForTests)

        let didReset = ModelContainerProvider.enforceStoreEpoch(
            defaults: defaults,
            appGroupStoreDirectory: appGroupDir,
            appSupportDirectory: appSupportDir,
            temporaryDirectory: tempDir
        )
        XCTAssertTrue(didReset)
        XCTAssertEqual(defaults.integer(forKey: ModelContainerProvider.storeEpochKeyForTests), ModelContainerProvider.currentStoreEpochForTests)

        XCTAssertFalse(fm.fileExists(atPath: appGroupDir.appendingPathComponent("BorderLog.store").path))
        XCTAssertFalse(fm.fileExists(atPath: appSupportDir.appendingPathComponent("BorderLog.store").path))
        XCTAssertFalse(fm.fileExists(atPath: tempDir.appendingPathComponent("BorderLog.fallback.store").path))

        let didResetAgain = ModelContainerProvider.enforceStoreEpoch(
            defaults: defaults,
            appGroupStoreDirectory: appGroupDir,
            appSupportDirectory: appSupportDir,
            temporaryDirectory: tempDir
        )
        XCTAssertFalse(didResetAgain)
    }
}
