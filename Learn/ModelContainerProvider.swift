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

enum BorderLogMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [BorderLogSchemaV1.self]
    static var stages: [MigrationStage] = []
}

enum ModelContainerProvider {
    private static let logger = Logger(subsystem: "com.MCCANN.Learn", category: "Persistence")

    static func makeContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: BorderLogSchemaV1.self)
        let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        if let appGroupId = AppConfig.appGroupId {
            let appGroupConfig = ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupId))
            do {
                return try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [appGroupConfig])
            } catch {
                logger.error("App Group store unavailable. Falling back to local store. Error: \(error, privacy: .public)")
            }
        } else {
            logger.error("AppGroupId missing or empty in Info.plist. Falling back to local store.")
        }

        do {
            return try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [fallbackConfig])
        } catch {
            logger.error("Local store unavailable. Falling back to in-memory store. Error: \(error, privacy: .public)")
            do {
                return try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [memoryConfig])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }
}
