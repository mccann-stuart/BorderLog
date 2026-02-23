//
//  ModelContainerProvider.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import Foundation
import SwiftData
import os

enum AppConfig {
    static let appGroupId: String? = {
        guard let groupId = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String else {
            return nil
        }
        let trimmed = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }()
}

enum BorderLogSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 0, 0)
    static var models: [any PersistentModel.Type] = [Stay.self, DayOverride.self]
}

enum BorderLogSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(2, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Stay.self,
        DayOverride.self,
        LocationSample.self,
        PhotoSignal.self,
        PresenceDay.self,
        PhotoIngestState.self
    ]
}

enum BorderLogSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(3, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Stay.self,
        DayOverride.self,
        LocationSample.self,
        PhotoSignal.self,
        PresenceDay.self,
        PhotoIngestState.self,
        CountryConfig.self
    ]
}

enum BorderLogMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [
        BorderLogSchemaV1.self,
        BorderLogSchemaV2.self,
        BorderLogSchemaV3.self
    ]
    static var stages: [MigrationStage] = [
        .lightweight(fromVersion: BorderLogSchemaV1.self, toVersion: BorderLogSchemaV2.self),
        .lightweight(fromVersion: BorderLogSchemaV2.self, toVersion: BorderLogSchemaV3.self)
    ]
}

enum ModelContainerProvider {
    private static let logger = Logger(subsystem: "com.MCCANN.Learn", category: "Persistence")

    static func makeContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: BorderLogSchemaV3.self)

        // Tier 1: App Group shared container (needed for widget access)
        if let appGroupId = AppConfig.appGroupId {
            let appGroupConfig = ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupId))
            do {
                let container = try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [appGroupConfig])
                logger.info("Using App Group store at group: \(appGroupId, privacy: .public)")
                return container
            } catch {
                // Migration failed — wipe the corrupt App Group store and fall through to local store.
                // "Unknown model version" means the store pre-dates the migration plan; we can't upgrade it.
                logger.error("App Group store migration failed. Deleting corrupt store and falling back to local. Error: \(error, privacy: .public)")
                if let appGroupRoot = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
                    deleteStoreFiles(in: appGroupRoot.appendingPathComponent("Library/Application Support"))
                }
            }
        } else {
            logger.warning("AppGroupId missing or empty in Info.plist. Using local store (widget will not share data).")
        }

        // Tier 2: Local on-disk store (no widget sharing, but data is preserved)
        // After deleting a corrupt App Group store above, try App Group one more time so widget keeps working.
        if let appGroupId = AppConfig.appGroupId {
            let appGroupConfig = ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupId))
            if let container = try? ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [appGroupConfig]) {
                logger.info("App Group store recreated successfully after recovery.")
                return container
            }
        }

        // Tier 3: Local on-disk fallback
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [localConfig])
            logger.info("Using local on-disk store.")
            return container
        } catch {
            logger.critical("Local store also failed. Deleting and recreating. Error: \(error, privacy: .public)")
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                deleteStoreFiles(in: appSupport)
            }
        }

        // Tier 4: Fresh local store after recovery deletion
        let recoveryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [recoveryConfig])
            logger.warning("Recovery succeeded — fresh local store created. Previous data was lost.")
            return container
        } catch {
            fatalError("Could not create a fresh SwiftData store after recovery. Error: \(error)")
        }
    }

    /// Deletes SwiftData SQLite store files (*.sqlite, *-shm, *-wal) from the given directory.
    private static func deleteStoreFiles(in directory: URL) {
        let fm = FileManager.default
        let bundleName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "default"
        let storeNames = ["\(bundleName).store", "default.store"]
        let sqliteSuffixes = [".sqlite", ".sqlite-shm", ".sqlite-wal"]

        for storeName in storeNames {
            for suffix in sqliteSuffixes {
                let url = directory.appendingPathComponent(storeName + suffix)
                guard fm.fileExists(atPath: url.path) else { continue }
                do {
                    try fm.removeItem(at: url)
                    logger.info("Deleted store file: \(url.lastPathComponent, privacy: .public)")
                } catch {
                    logger.error("Failed to delete \(url.lastPathComponent, privacy: .public): \(error, privacy: .public)")
                }
            }
        }
    }
}
