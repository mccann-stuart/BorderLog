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
    static let appGroupId = "group.com.MCCANN.Learn"
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
        let appGroupConfig = ModelConfiguration(schema: schema, groupContainer: .identifier(AppConfig.appGroupId))
        let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [appGroupConfig])
        } catch {
            logger.error("App Group store unavailable. Falling back to local store. Error: \(error, privacy: .public)")
            do {
                return try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [fallbackConfig])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }
}
