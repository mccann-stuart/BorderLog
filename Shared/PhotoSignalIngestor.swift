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
        case sequenced
    }

    private var resolver: CountryResolving?
    internal var saveContextOverride: (@Sendable () throws -> Void)?

    struct IngestQueryConfig {
        let startDate: Date
        let endDate: Date?
        let sortAscending: Bool
    }

    init(modelContainer: ModelContainer, resolver: CountryResolving) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.resolver = resolver
    }

    func ingest(mode: IngestMode) async throws -> Int {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return 0
        }

        var didBeginScan = false
        defer {
            if didBeginScan {
                Task { @MainActor in
                    InferenceActivity.shared.endPhotoScan()
                }
            }
        }

        let state = fetchOrCreateState()

        let calendar = Calendar.current
        let now = Date()

        let config = Self.ingestQueryConfig(mode: mode, state: state, now: now, calendar: calendar)

        let options = PHFetchOptions()
        if let endDate = config.endDate {
            options.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                config.startDate as NSDate,
                endDate as NSDate
            )
        } else {
            options.predicate = NSPredicate(format: "creationDate >= %@", config.startDate as NSDate)
        }
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: config.sortAscending)]

        let assets = PHAsset.fetchAssets(with: .image, options: options)
        let assetCount = assets.count
        var existingAssetHashes = try fetchExistingAssetIdHashes(config: config)

        if assetCount > 0 {
            await MainActor.run {
                InferenceActivity.shared.beginPhotoScan(totalAssets: assetCount)
            }
            didBeginScan = true
        }

        var processed = 0
        var touchedDayKeys: Set<String> = []
        let saveEvery = 25
        let progressUpdateEvery = 25
        var didSetSequencedCheckpoint = false

        if assetCount > 0 {
            for index in 0..<assetCount {
                let asset = assets.object(at: index)
                let scannedAssets = index + 1
                if scannedAssets % progressUpdateEvery == 0 || scannedAssets == assetCount {
                    await MainActor.run {
                        InferenceActivity.shared.updatePhotoScanProgress(scannedAssets: scannedAssets)
                    }
                }
                guard let creationDate = asset.creationDate,
                      let location = asset.location else {
                    continue
                }

                let assetIdHash = Self.hashAssetId(asset.localIdentifier)
                if existingAssetHashes.contains(assetIdHash) {
                    continue
                }

                if mode == .sequenced, !didSetSequencedCheckpoint {
                    state.lastAssetCreationDate = creationDate
                    state.lastAssetIdHash = assetIdHash
                    didSetSequencedCheckpoint = true
                }

                let activeResolver: CountryResolving
                if let storedResolver = self.resolver {
                    activeResolver = storedResolver
                } else {
                    let createdResolver = await MainActor.run { CLGeocoderCountryResolver() }
                    activeResolver = createdResolver
                    self.resolver = createdResolver
                }
                let resolution = await activeResolver.resolveCountry(for: location)
                let timeZone = resolution?.timeZone ?? TimeZone.current
                let dayKey = await DayKey.make(from: creationDate, timeZone: timeZone)

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
                existingAssetHashes.insert(assetIdHash)
                touchedDayKeys.insert(dayKey)

                if mode != .sequenced {
                    state.lastAssetCreationDate = creationDate
                    state.lastAssetIdHash = assetIdHash
                }
                state.lastIngestedAt = Date()
                if mode == .manualFullScan {
                    state.fullScanCompleted = true
                    state.lastFullScanAt = Date()
                }
                processed += 1

                if processed % saveEvery == 0, modelContext.hasChanges {
                    try saveContextIfNeeded()
                }
            }
        }

        if mode == .sequenced {
            state.fullScanCompleted = true
            state.lastFullScanAt = now
        }

        try saveContextIfNeeded()

        if !touchedDayKeys.isEmpty {
            let recomputeService = LedgerRecomputeService(modelContainer: modelContainer)
            await recomputeService.recompute(dayKeys: Array(touchedDayKeys))
        }

        return processed
    }

    static func ingestQueryConfig(
        mode: IngestMode,
        state: PhotoIngestState,
        now: Date,
        calendar: Calendar
    ) -> IngestQueryConfig {
        switch mode {
        case .sequenced:
            let startDate = calendar.date(byAdding: .day, value: -730, to: now) ?? now
            return IngestQueryConfig(startDate: startDate, endDate: now, sortAscending: false)
        case .manualFullScan:
            return IngestQueryConfig(startDate: Date.distantPast, endDate: nil, sortAscending: true)
        case .auto:
            if let lastDate = state.lastAssetCreationDate {
                return IngestQueryConfig(
                    startDate: lastDate.addingTimeInterval(1),
                    endDate: nil,
                    sortAscending: true
                )
            }
            let startDate = calendar.date(byAdding: .month, value: -12, to: now) ?? now
            return IngestQueryConfig(startDate: startDate, endDate: nil, sortAscending: true)
        }
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

    internal func fetchExistingAssetIdHashes(config: IngestQueryConfig) throws -> Set<String> {
        let startDate = config.startDate
        let descriptor: FetchDescriptor<PhotoSignal>
        if let endDate = config.endDate {
            descriptor = FetchDescriptor<PhotoSignal>(
                predicate: #Predicate { signal in
                    signal.timestamp >= startDate && signal.timestamp <= endDate
                }
            )
        } else {
            descriptor = FetchDescriptor<PhotoSignal>(
                predicate: #Predicate { signal in
                    signal.timestamp >= startDate
                }
            )
        }
        return Set(try modelContext.fetch(descriptor).map(\.assetIdHash))
    }

    internal func saveContextIfNeeded() throws {
        guard modelContext.hasChanges else { return }
        if let saveContextOverride {
            try saveContextOverride()
        } else {
            try modelContext.save()
        }
    }

    internal func addTestSignal(assetIdHash: String, timestamp: Date = Date()) {
        let dayKey = DayKey.make(from: timestamp, timeZone: .current)
        let signal = PhotoSignal(
            timestamp: timestamp,
            latitude: 0,
            longitude: 0,
            assetIdHash: assetIdHash,
            timeZoneId: TimeZone.current.identifier,
            dayKey: dayKey,
            countryCode: "GB",
            countryName: "United Kingdom"
        )
        modelContext.insert(signal)
    }

    internal func setSaveOverride(_ override: (@Sendable () throws -> Void)?) {
        saveContextOverride = override
    }

    private static func hashAssetId(_ identifier: String) -> String {
        let data = Data(identifier.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
