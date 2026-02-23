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
                // Fall through to local store — log but don't crash.
                logger.error("App Group store failed. Falling back to local store. Error: \(error, privacy: .public)")
            }
        } else {
            logger.warning("AppGroupId missing or empty in Info.plist. Using local store (widget will not share data).")
        }

        // Tier 2: Local on-disk store (no widget sharing, but data is preserved)
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [localConfig])
            logger.info("Using local on-disk store.")
            return container
        } catch {
            // Migration or load failure — the store file is corrupt or incompatible.
            // Recovery: delete the broken store files and create a fresh one.
            // This loses persisted data but is far better than crashing in production
            // or silently running on an in-memory store every launch.
            logger.critical("Local store failed to open/migrate. Attempting recovery by deleting corrupt store. Error: \(error, privacy: .public)")
            deleteLocalStoreFiles()
        }

        // Tier 3: Fresh local store after recovery deletion
        let recoveryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [recoveryConfig])
            logger.warning("Recovery succeeded — started with a fresh local store. All previous data was lost.")
            return container
        } catch {
            fatalError("Could not create a fresh SwiftData store after recovery. Error: \(error)")
        }
    }

    /// Deletes the default SwiftData SQLite store files from the app's Application Support directory.
    private static func deleteLocalStoreFiles() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        // SwiftData stores files named after the app bundle name (e.g., "Learn.store.sqlite").
        // Cover both the bundle-name variant and the "default" fallback name.
        let bundleName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "default"
        let storeNames = ["\(bundleName).store", "default.store"]
        let sqliteSuffixes = [".sqlite", ".sqlite-shm", ".sqlite-wal"]

        for storeName in storeNames {
            for suffix in sqliteSuffixes {
                let url = appSupport.appendingPathComponent(storeName + suffix)
                guard fm.fileExists(atPath: url.path) else { continue }
                do {
                    try fm.removeItem(at: url)
                    logger.info("Deleted corrupt store file: \(url.lastPathComponent, privacy: .public)")
                } catch {
                    logger.error("Failed to delete \(url.lastPathComponent, privacy: .public): \(error, privacy: .public)")
                }
            }
        }
    }
}
