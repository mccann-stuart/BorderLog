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
        if let groupId = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String {
            let trimmed = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return "group.com.MCCANN.Border"
    }()

    static var appGroupContainerURL: URL? {
        guard let appGroupId else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    }

    static var isAppGroupAvailable: Bool {
        appGroupContainerURL != nil
    }

    static let cloudKitContainerId = "iCloud.com.MCCANN.BorderLog"
    static let isCloudKitFeatureEnabled = false

    static var sharedDefaults: UserDefaults {
        if isAppGroupAvailable, let appGroupId = appGroupId, let defaults = UserDefaults(suiteName: appGroupId) {
            return defaults
        }
        return .standard
    }

    static var isCloudKitSyncEnabled: Bool {
        sharedDefaults.bool(forKey: "cloudKitSyncEnabled")
    }
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
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase =
            (AppConfig.isCloudKitFeatureEnabled && AppConfig.isCloudKitSyncEnabled)
                ? .private(AppConfig.cloudKitContainerId)
                : .none

        // Tier 1: App Group shared container (needed for widget access)
        if AppConfig.isAppGroupAvailable, let appGroupId = AppConfig.appGroupId {
            let appGroupConfig = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupId),
                cloudKitDatabase: cloudKitDatabase
            )
            do {
                let container = try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [appGroupConfig])
                logger.info("Using App Group store at group: \(appGroupId, privacy: .public)")
                return container
            } catch {
                logger.error("App Group store open failed. Attempting quarantine recovery. Error: \(error, privacy: .public)")
                if let appGroupRoot = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
                    let appGroupSupport = appGroupRoot.appendingPathComponent("Library/Application Support")
                    if let recovered = recoverByQuarantiningStore(
                        schema: schema,
                        configuration: appGroupConfig,
                        storeDirectory: appGroupSupport,
                        storeNames: ["default.store", "Learn.store", "BorderLog.store"],
                        initialError: error,
                        contextLabel: "App Group"
                    ) {
                        return recovered
                    }
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

        let storeURL = appSupport.appendingPathComponent("BorderLog.store")
        let localConfig = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: cloudKitDatabase)
        do {
            let container = try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [localConfig])
            logger.info("Using local sandbox store at: \(storeURL.lastPathComponent, privacy: .public)")
            return container
        } catch {
            logger.error("Local store open failed. Attempting quarantine recovery. Error: \(error, privacy: .public)")
            if let recovered = recoverByQuarantiningStore(
                schema: schema,
                configuration: localConfig,
                storeDirectory: appSupport,
                storeNames: ["BorderLog.store"],
                initialError: error,
                contextLabel: "Local"
            ) {
                return recovered
            }
        }

        logger.critical("All persistent store options failed. Falling back to in-memory store.")
        return makeInMemoryContainer(schema: schema)
    }

    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [memConfig])
        } catch {
            logger.critical("In-memory store init failed. Attempting temporary file-backed fallback. Error: \(error, privacy: .public)")
            do {
                return try makeTemporaryFallbackContainer(schema: schema)
            } catch {
                fatalError("Unable to initialize any SwiftData container: \(error)")
            }
        }
    }

    private static func makeTemporaryFallbackContainer(schema: Schema) throws -> ModelContainer {
        let fallbackDirectory = FileManager.default.temporaryDirectory
        let fallbackStoreName = "BorderLog.fallback.store"
        deleteStoreFiles(in: fallbackDirectory, named: fallbackStoreName)
        let fallbackURL = fallbackDirectory.appendingPathComponent(fallbackStoreName)
        let fallbackConfig = ModelConfiguration(schema: schema, url: fallbackURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [fallbackConfig])
        logger.warning("Using temporary file-backed fallback store: \(fallbackStoreName, privacy: .public)")
        return container
    }

    private static func recoverByQuarantiningStore(
        schema: Schema,
        configuration: ModelConfiguration,
        storeDirectory: URL,
        storeNames: [String],
        initialError: Error,
        contextLabel: String
    ) -> ModelContainer? {
        guard shouldAttemptRecovery(for: initialError) else {
            logger.error("\(contextLabel, privacy: .public) store failure does not match recovery heuristics; skipping destructive paths.")
            return nil
        }

        let quarantineTag = Self.quarantineTag()
        var quarantinedAny = false
        for storeName in storeNames {
            quarantinedAny = quarantineStoreFiles(in: storeDirectory, named: storeName, quarantineTag: quarantineTag) || quarantinedAny
        }
        guard quarantinedAny else {
            logger.error("\(contextLabel, privacy: .public) recovery skipped; no store files available to quarantine.")
            return nil
        }

        do {
            let container = try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [configuration])
            logger.warning("\(contextLabel, privacy: .public) store recovered by quarantining prior files with tag \(quarantineTag, privacy: .public).")
            return container
        } catch {
            logger.error("\(contextLabel, privacy: .public) quarantine recovery failed. Error: \(error, privacy: .public)")
            guard shouldDeleteAfterRecoveryFailure(for: error) else {
                return nil
            }

            logger.error("\(contextLabel, privacy: .public) failure matches corruption heuristics; deleting active store files and retrying once.")
            for storeName in storeNames {
                deleteStoreFiles(in: storeDirectory, named: storeName)
            }

            do {
                let container = try ModelContainer(for: schema, migrationPlan: BorderLogMigrationPlan.self, configurations: [configuration])
                logger.warning("\(contextLabel, privacy: .public) store recreated after quarantine + corruption-confirmed delete.")
                return container
            } catch {
                logger.critical("\(contextLabel, privacy: .public) store recreation failed after delete. Error: \(error, privacy: .public)")
                return nil
            }
        }
    }

    internal static func shouldAttemptRecovery(for error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        let keywords = [
            "migration",
            "incompatible",
            "schema",
            "model",
            "sqlite",
            "database",
            "corrupt",
            "corruption",
            "malformed",
            "cannot open",
            "i/o"
        ]
        return keywords.contains(where: { message.contains($0) })
    }

    internal static func shouldDeleteAfterRecoveryFailure(for error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        let corruptionIndicators = [
            "database disk image is malformed",
            "disk image is malformed",
            "not a database",
            "file is encrypted or is not a database",
            "corrupt",
            "corruption",
            "malformed",
            "i/o error"
        ]
        return corruptionIndicators.contains(where: { message.contains($0) })
    }

    private static func quarantineTag() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let raw = formatter.string(from: Date())
        return raw
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "Z", with: "Z")
    }

    /// Moves a named SwiftData store and sidecar files to quarantine files.
    /// Returns true if at least one file was quarantined.
    @discardableResult
    internal static func quarantineStoreFiles(in directory: URL, named storeName: String, quarantineTag: String) -> Bool {
        let fm = FileManager.default
        var movedAny = false
        for suffix in ["", "-wal", "-shm"] {
            let sourceURL = directory.appendingPathComponent(storeName + suffix)
            guard fm.fileExists(atPath: sourceURL.path) else { continue }
            let destinationURL = directory.appendingPathComponent("\(storeName)\(suffix).quarantine-\(quarantineTag)")
            do {
                if fm.fileExists(atPath: destinationURL.path) {
                    try fm.removeItem(at: destinationURL)
                }
                try fm.moveItem(at: sourceURL, to: destinationURL)
                movedAny = true
                logger.warning("Quarantined store file: \(sourceURL.lastPathComponent, privacy: .public)")
            } catch {
                logger.error("Failed to quarantine \(sourceURL.lastPathComponent, privacy: .public): \(error, privacy: .public)")
            }
        }
        return movedAny
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
