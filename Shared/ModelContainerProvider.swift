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
        BorderLogSchemaV4.PresenceDay.self,
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
        BorderLogSchemaV4.PresenceDay.self,
        PhotoIngestState.self,
        CountryConfig.self
    ]
}

enum BorderLogSchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(4, 0, 0)

    @Model
    final class PresenceDay {
        @Attribute(.unique) var dayKey: String
        var date: Date
        var timeZoneId: String?
        var countryCode: String?
        var countryName: String?
        var confidence: Double
        var confidenceLabelRaw: String
        var sourcesRaw: Int
        var isOverride: Bool
        var stayCount: Int
        var photoCount: Int
        var locationCount: Int
        var calendarCount: Int = 0
        var suggestedCountryCode1: String?
        var suggestedCountryName1: String?
        var suggestedCountryCode2: String?
        var suggestedCountryName2: String?

        init(
            dayKey: String,
            date: Date,
            timeZoneId: String?,
            countryCode: String?,
            countryName: String?,
            confidence: Double,
            confidenceLabelRaw: String,
            sourcesRaw: Int,
            isOverride: Bool,
            stayCount: Int,
            photoCount: Int,
            locationCount: Int,
            calendarCount: Int = 0,
            suggestedCountryCode1: String? = nil,
            suggestedCountryName1: String? = nil,
            suggestedCountryCode2: String? = nil,
            suggestedCountryName2: String? = nil
        ) {
            self.dayKey = dayKey
            self.date = date
            self.timeZoneId = timeZoneId
            self.countryCode = countryCode
            self.countryName = countryName
            self.confidence = confidence
            self.confidenceLabelRaw = confidenceLabelRaw
            self.sourcesRaw = sourcesRaw
            self.isOverride = isOverride
            self.stayCount = stayCount
            self.photoCount = photoCount
            self.locationCount = locationCount
            self.calendarCount = calendarCount
            self.suggestedCountryCode1 = suggestedCountryCode1
            self.suggestedCountryName1 = suggestedCountryName1
            self.suggestedCountryCode2 = suggestedCountryCode2
            self.suggestedCountryName2 = suggestedCountryName2
        }
    }

    static var models: [any PersistentModel.Type] = [
        Stay.self,
        DayOverride.self,
        LocationSample.self,
        PhotoSignal.self,
        PresenceDay.self,
        PhotoIngestState.self,
        CountryConfig.self,
        CalendarSignal.self
    ]
}

enum BorderLogSchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(5, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Stay.self,
        DayOverride.self,
        LocationSample.self,
        PhotoSignal.self,
        PresenceDay.self,
        PhotoIngestState.self,
        CountryConfig.self,
        CalendarSignal.self
    ]
}

enum BorderLogMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [
        BorderLogSchemaV1.self,
        BorderLogSchemaV2.self,
        BorderLogSchemaV3.self,
        BorderLogSchemaV4.self,
        BorderLogSchemaV5.self
    ]
    static var stages: [MigrationStage] = [
        .lightweight(fromVersion: BorderLogSchemaV1.self, toVersion: BorderLogSchemaV2.self),
        .lightweight(fromVersion: BorderLogSchemaV2.self, toVersion: BorderLogSchemaV3.self),
        .lightweight(fromVersion: BorderLogSchemaV3.self, toVersion: BorderLogSchemaV4.self),
        .lightweight(fromVersion: BorderLogSchemaV4.self, toVersion: BorderLogSchemaV5.self)
    ]
}

enum ModelContainerProvider {
    private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "Persistence")

    static func makeContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: BorderLogSchemaV5.self)

        // Tier 1: App Group shared container (needed for widget access)
        if let appGroupId = AppConfig.appGroupId {
            let appGroupConfig = ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupId))
            do {
                let container = try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [appGroupConfig])
                logger.info("Using App Group store at group: \(appGroupId, privacy: .public)")
                return container
            } catch {
                logger.error("App Group store migration failed. Deleting and retrying. Error: \(error, privacy: .public)")
                cleanupAppGroupStore(appGroupId: appGroupId)
                // Retry App Group after cleanup
                if let container = try? ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [appGroupConfig]) {
                    logger.info("App Group store recreated after cleanup.")
                    return container
                }
            }
        }

        // Tier 2: Local sandbox store with explicit URL.
        // IMPORTANT: Always specify an explicit URL to prevent SwiftData from defaulting
        // to the App Group container (which happens when no URL is given and the app has
        // an App Group entitlement, even without a groupContainer configuration).
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.critical("Cannot locate Application Support directory — using in-memory store.")
            return makeInMemoryContainer(schema: schema)
        }

        // First, clean up any corrupt App Group store files we know about.
        // The AppGroupId may be missing from Info.plist but the entitlement can still
        // cause SwiftData to route to the App Group path as its "default" store.
        let knownGroupId = "group.com.MCCANN.Border"
        cleanupAppGroupStore(appGroupId: knownGroupId)

        let storeURL = appSupport.appendingPathComponent("BorderLog.store")
        let localConfig = ModelConfiguration(schema: schema, url: storeURL)
        do {
            let container = try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [localConfig])
            logger.info("Using local sandbox store at: \(storeURL.lastPathComponent, privacy: .public)")
            return container
        } catch {
            // Corrupt or unmigratable local store — delete and recreate fresh.
            logger.critical("Local store failed. Deleting and recreating. Error: \(error, privacy: .public)")
            deleteStoreFiles(in: appSupport, named: "BorderLog.store")
        }

        // Tier 3: Fresh local store after wiping corrupt files
        do {
            let container = try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [localConfig])
            logger.warning("Recovery succeeded — fresh local store at \(storeURL.lastPathComponent, privacy: .public). Previous data was lost.")
            return container
        } catch {
            logger.critical("All store options failed. Falling back to in-memory store. Error: \(error, privacy: .public)")
            return makeInMemoryContainer(schema: schema)
        }
    }

    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [memConfig])
    }

    /// Deletes the App Group SwiftData store files for the given group identifier.
    private static func cleanupAppGroupStore(appGroupId: String) {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return }
        let dir = root.appendingPathComponent("Library/Application Support")
        deleteStoreFiles(in: dir, named: "default.store")
        deleteStoreFiles(in: dir, named: "Learn.store")
    }

    /// Deletes a named SwiftData store and its -wal/-shm sidecar files from the given directory.
    /// CoreData stores the SQLite file using the store name directly (e.g. "BorderLog.store"),
    /// with -wal and -shm dash-suffixed variants alongside it.
    private static func deleteStoreFiles(in directory: URL, named storeName: String) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
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
