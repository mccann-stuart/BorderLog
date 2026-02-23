//
//  CloudKitDataResetService.swift
//  Learn
//
//  Created by Codex on 23/02/2026.
//

import CloudKit
import os

enum CloudKitDataResetService {
    private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "CloudKitReset")

    static func deleteAllUserData() async throws {
        let container = CKContainer(identifier: AppConfig.cloudKitContainerId)
        let database = container.privateCloudDatabase
        let zones = try await fetchAllZones(in: database)
        let defaultZoneID = CKRecordZone.default().zoneID
        let zoneIDsToDelete = zones.map(\.zoneID).filter { $0 != defaultZoneID }

        guard !zoneIDsToDelete.isEmpty else {
            logger.info("No custom CloudKit record zones to delete.")
            return
        }

        try await deleteZones(zoneIDsToDelete, in: database)
        logger.info("Deleted \(zoneIDsToDelete.count) CloudKit record zones.")
    }

    private static func fetchAllZones(in database: CKDatabase) async throws -> [CKRecordZone] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CKRecordZone], Error>) in
            database.fetchAllRecordZones { zones, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: zones ?? [])
            }
        }
    }

    private static func deleteZones(_ zoneIDs: [CKRecordZone.ID], in database: CKDatabase) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.modifyRecordZones(saving: [], deleting: zoneIDs) { result in
                switch result {
                case .failure(let error):
                    continuation.resume(throwing: error)
                case .success:
                    continuation.resume()
                }
            }
        }
    }
}
