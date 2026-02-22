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

@ModelActor
actor PhotoSignalIngestor {
    enum IngestMode {
        case auto
        case manualFullScan
    }

    private var resolver: CountryResolving?

    init(modelContainer: ModelContainer, resolver: CountryResolving) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.resolver = resolver
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
        options.predicate = NSPredicate(format: "creationDate >= %@", startDate as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(with: .image, options: options)
        let assetCount = assets.count

        var processed = 0
        var touchedDayKeys: Set<String> = []

        if assetCount > 0 {
            // Ensure resolver is initialized
            if self.resolver == nil {
                self.resolver = await MainActor.run { CLGeocoderCountryResolver() }
            }
            let activeResolver = self.resolver!

            let batchSize = 5
            var index = 0

            while index < assetCount {
                let end = min(index + batchSize, assetCount)
                let range = index..<end

                var validAssets: [(Int, PHAsset, String)] = []

                // 1. Identify valid candidates serially (fast)
                for i in range {
                    let asset = assets.object(at: i)
                    guard let _ = asset.creationDate,
                          let _ = asset.location else {
                        continue
                    }

                    let assetIdHash = Self.hashAssetId(asset.localIdentifier)
                    if Self.photoSignalExists(assetIdHash: assetIdHash, in: modelContext) {
                        continue
                    }
                    validAssets.append((i, asset, assetIdHash))
                }

                if !validAssets.isEmpty {
                    // 2. Process geocoding and key generation concurrently
                    await withTaskGroup(of: IngestResult?.self) { group in
                        for (i, asset, assetIdHash) in validAssets {
                            // Safe unwraps known to be valid from step 1
                            let creationDate = asset.creationDate!
                            let location = asset.location!

                            group.addTask { [creationDate, location, assetIdHash] in
                                let resolution = await activeResolver.resolveCountry(for: location)
                                let timeZone = resolution?.timeZone ?? TimeZone.current
                                let dayKey = DayKey.make(from: creationDate, timeZone: timeZone)

                                return IngestResult(
                                    index: i,
                                    creationDate: creationDate,
                                    location: location,
                                    assetIdHash: assetIdHash,
                                    resolution: resolution,
                                    dayKey: dayKey
                                )
                            }
                        }

                        // 3. Collect and Sort Results
                        var batchResults: [IngestResult] = []
                        for await result in group {
                            if let result {
                                batchResults.append(result)
                            }
                        }
                        batchResults.sort { $0.index < $1.index }

                        // 4. Insert serially
                        for result in batchResults {
                            let signal = PhotoSignal(
                                timestamp: result.creationDate,
                                latitude: result.location.coordinate.latitude,
                                longitude: result.location.coordinate.longitude,
                                assetIdHash: result.assetIdHash,
                                timeZoneId: result.resolution?.timeZone?.identifier,
                                dayKey: result.dayKey,
                                countryCode: result.resolution?.countryCode,
                                countryName: result.resolution?.countryName
                            )
                            modelContext.insert(signal)
                            touchedDayKeys.insert(result.dayKey)

                            state.lastAssetCreationDate = result.creationDate
                            state.lastAssetIdHash = result.assetIdHash
                            state.lastIngestedAt = Date()
                            if mode == .manualFullScan {
                                state.fullScanCompleted = true
                                state.lastFullScanAt = Date()
                            }
                            processed += 1
                        }
                    }

                    if modelContext.hasChanges {
                        try? modelContext.save()
                    }
                }

                index = end
            }
        }

        if modelContext.hasChanges {
            try? modelContext.save()
        }

        if !touchedDayKeys.isEmpty {
            let recomputeService = LedgerRecomputeService(modelContainer: modelContainer)
            await recomputeService.recompute(dayKeys: Array(touchedDayKeys))
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

private struct IngestResult: Sendable {
    let index: Int
    let creationDate: Date
    let location: CLLocation
    let assetIdHash: String
    let resolution: CountryResolution?
    let dayKey: String
}
