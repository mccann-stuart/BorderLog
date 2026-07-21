import XCTest
import SwiftData
@testable import Learn

final class ModelContainerProviderRecoveryTests: XCTestCase {
    func testMakeContainerAppGroupQuarantineRecovery() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("AppGroupRecoveryTests-\(UUID().uuidString)")
        let appGroupRoot = root.appendingPathComponent("group")
        let appGroupSupport = appGroupRoot.appendingPathComponent("Library/Application Support")
        try fm.createDirectory(at: appGroupSupport, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let storeNames = ["default.store", "Learn.store", "BorderLog.store"]
        for storeName in storeNames {
            let storeURL = appGroupSupport.appendingPathComponent(storeName)
            try Data("corrupted data".utf8).write(to: storeURL)
        }

        var attempts = 0
        let containerBuilder: (Schema, ModelConfiguration) throws -> ModelContainer = { schema, config in
            attempts += 1
            if attempts == 1 {
                // Simulate first open failure due to corruption
                throw StubError(description: "database disk image is malformed")
            }
            // For testing purposes, we return a fallback container on retry
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [memConfig])
        }

        let container = try ModelContainerProvider.makeContainer(
            isAppGroupAvailable: true,
            appGroupId: "test.group",
            appGroupContainerURL: appGroupRoot,
            appSupportDirectory: nil,
            containerBuilder: containerBuilder
        )

        XCTAssertNotNil(container, "Expected recovery to succeed and return a container")
        XCTAssertEqual(attempts, 2, "Expected exactly 2 initialization attempts (1st fails, 2nd succeeds after quarantine)")

        for storeName in storeNames {
            let quarantinedFiles = try fm.contentsOfDirectory(atPath: appGroupSupport.path).filter { $0.starts(with: storeName) && $0.contains(".quarantine-") }
            XCTAssertFalse(quarantinedFiles.isEmpty, "Expected store file \(storeName) to be quarantined")
            let originalFile = appGroupSupport.appendingPathComponent(storeName)
            XCTAssertFalse(fm.fileExists(atPath: originalFile.path), "Expected original store file \(storeName) to be removed/moved")
        }
    }

    func testMakeContainerLocalStoreQuarantineRecovery() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("LocalRecoveryTests-\(UUID().uuidString)")
        let appSupport = root.appendingPathComponent("Library/Application Support")
        try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let storeNames = ["BorderLog.store"]
        for storeName in storeNames {
            let storeURL = appSupport.appendingPathComponent(storeName)
            try Data("corrupted data".utf8).write(to: storeURL)
        }

        var attempts = 0
        let containerBuilder: (Schema, ModelConfiguration) throws -> ModelContainer = { schema, config in
            attempts += 1
            if attempts == 1 {
                throw StubError(description: "database disk image is malformed")
            }
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [memConfig])
        }

        let container = try ModelContainerProvider.makeContainer(
            isAppGroupAvailable: false,
            appGroupId: nil,
            appGroupContainerURL: nil,
            appSupportDirectory: appSupport,
            containerBuilder: containerBuilder
        )

        XCTAssertNotNil(container, "Expected recovery to succeed and return a container")
        XCTAssertEqual(attempts, 2, "Expected exactly 2 initialization attempts (1st fails, 2nd succeeds after quarantine)")

        for storeName in storeNames {
            let quarantinedFiles = try fm.contentsOfDirectory(atPath: appSupport.path).filter { $0.starts(with: storeName) && $0.contains(".quarantine-") }
            XCTAssertFalse(quarantinedFiles.isEmpty, "Expected store file \(storeName) to be quarantined")
        }
    }

    func testMakeContainerLocalStoreRealCorruptionRecovery() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("LocalRealCorruptionRecoveryTests-\(UUID().uuidString)")
        let appSupport = root.appendingPathComponent("Library/Application Support")
        try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        // Create a dummy valid store first so it generates sidecar files
        // We do this to ensure it's fully populated, then we corrupt the main file.
        let storeURL = appSupport.appendingPathComponent("BorderLog.store")
        let schema = Schema(versionedSchema: BorderLogSchemaV7.self)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)

        do {
            let initialContainer = try ModelContainer(for: schema, configurations: [config])
            // Force save some data if needed, but creating it is usually enough to write the file.
            _ = initialContainer
        } catch {
            XCTFail("Failed to create initial valid store: \(error)")
        }

        // Corrupt the main store file to trigger a real SQLite malformed/corruption error
        try Data("garbage non-sqlite data".utf8).write(to: storeURL)

        // Now call the real makeContainer without a containerBuilder
        // This will hit the real SwiftData initializer and throw an error,
        // which should trigger quarantine and recreate the store.
        let container = ModelContainerProvider.makeContainer(
            isAppGroupAvailable: false,
            appGroupId: nil,
            appGroupContainerURL: nil,
            appSupportDirectory: appSupport,
            containerBuilder: nil
        )

        XCTAssertNotNil(container, "Expected recovery to succeed and return a new container")

        let storeNames = ["BorderLog.store"]
        for storeName in storeNames {
            let quarantinedFiles = try fm.contentsOfDirectory(atPath: appSupport.path).filter { $0.starts(with: storeName) && $0.contains(".quarantine-") }
            XCTAssertFalse(quarantinedFiles.isEmpty, "Expected store file \(storeName) to be quarantined")

            // Check that a new valid store was recreated in its place
            let originalFile = appSupport.appendingPathComponent(storeName)
            XCTAssertTrue(fm.fileExists(atPath: originalFile.path), "Expected a new valid store file \(storeName) to be created after quarantine")
        }
    }

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
