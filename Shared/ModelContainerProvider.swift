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
                // Migration errors must NOT silently fall back to memory — that would wipe all data.
                // Log clearly. We fall through to local store as a recovery path.
                logger.error("App Group store failed (possible migration issue). Falling back to local store. Error: \(error, privacy: .public)")
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
            // A migration failure here means stored data cannot be opened.
            // Do NOT fall back to in-memory — that silently wipes all persisted data.
            // Crash loudly in debug; in production the caller can decide how to handle.
            logger.critical("Local store migration/creation failed. This is a critical error. Error: \(error, privacy: .public)")
            fatalError("Could not open or migrate the local SwiftData store: \(error)\n\nDelete and reinstall the app if you are in development.")
        }
    }
}
