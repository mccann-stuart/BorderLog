//
//  PhotoSignalIngestor.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import Photos
import CryptoKit
import SwiftData
import CoreLocation

@MainActor
struct PhotoSignalIngestor {
    enum IngestMode {
        case auto
        case manualFullScan
    }

    let modelContext: ModelContext
    let resolver: CountryResolving

    init(modelContext: ModelContext, resolver: CountryResolving) {
        self.modelContext = modelContext
        self.resolver = resolver
    }

    init(modelContext: ModelContext) {
        self.init(modelContext: modelContext, resolver: CLGeocoderCountryResolver())
    }

    func ingest(mode: IngestMode) async -> Int {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return 0
        }

        let state = fetchOrCreateState()

        let calendar = Calendar.current
        let now = Date()

        let startDate: Date
        switch mode {
        case .manualFullScan:
            startDate = Date.distantPast
        case .auto:
            if let lastDate = state.lastAssetCreationDate {
                startDate = lastDate.addingTimeInterval(1)
            } else {
                startDate = calendar.date(byAdding: .month, value: -12, to: now) ?? now
            }
        }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND location != nil", startDate as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(with: .image, options: options)
        let assetCount = assets.count

        var processed = 0
        var touchedDayKeys: Set<String> = []

        if assetCount > 0 {
            for index in 0..<assetCount {
                let asset = assets.object(at: index)
                guard let creationDate = asset.creationDate,
                      let location = asset.location else {
                    continue
                }

                let assetIdHash = Self.hashAssetId(asset.localIdentifier)
                if Self.photoSignalExists(assetIdHash: assetIdHash, in: modelContext) {
                    continue
                }

                let resolution = await resolver.resolveCountry(for: location)
                let timeZone = resolution?.timeZone ?? TimeZone.current
                let dayKey = DayKey.make(from: creationDate, timeZone: timeZone)

                let signal = PhotoSignal(
                    timestamp: creationDate,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    assetIdHash: assetIdHash,
                    timeZoneId: resolution?.timeZone?.identifier,
                    dayKey: dayKey,
                    countryCode: resolution?.countryCode,
                    countryName: resolution?.countryName
                )
                modelContext.insert(signal)
                touchedDayKeys.insert(dayKey)

                state.lastAssetCreationDate = creationDate
                state.lastAssetIdHash = assetIdHash
                state.lastIngestedAt = Date()
                if mode == .manualFullScan {
                    state.fullScanCompleted = true
                    state.lastFullScanAt = Date()
                }
                processed += 1
            }
        }

        if !touchedDayKeys.isEmpty {
            await LedgerRecomputeService.recompute(dayKeys: Array(touchedDayKeys), modelContext: modelContext)
        }

        return processed
    }

    private func fetchOrCreateState() -> PhotoIngestState {
        let descriptor = FetchDescriptor<PhotoIngestState>()
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let state = PhotoIngestState()
        modelContext.insert(state)
        return state
    }

    private static func photoSignalExists(assetIdHash: String, in modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<PhotoSignal>(predicate: #Predicate { $0.assetIdHash == assetIdHash })
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    private static func hashAssetId(_ identifier: String) -> String {
        let data = Data(identifier.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
