//
//  PhotoIngestState.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import SwiftData

@Model
nonisolated final class PhotoIngestState {
    var lastIngestedAt: Date?
    var lastAssetCreationDate: Date?
    var lastAssetIdHash: String?
    var fullScanCompleted: Bool
    var lastFullScanAt: Date?

    init(
        lastIngestedAt: Date? = nil,
        lastAssetCreationDate: Date? = nil,
        lastAssetIdHash: String? = nil,
        fullScanCompleted: Bool = false,
        lastFullScanAt: Date? = nil
    ) {
        self.lastIngestedAt = lastIngestedAt
        self.lastAssetCreationDate = lastAssetCreationDate
        self.lastAssetIdHash = lastAssetIdHash
        self.fullScanCompleted = fullScanCompleted
        self.lastFullScanAt = lastFullScanAt
    }
}
