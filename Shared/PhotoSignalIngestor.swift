//
//  PhotoSignalIngestor.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import Photos
import ImageIO
import CryptoKit
import SwiftData
import CoreLocation

nonisolated struct PhotoCaptureMetadata: Equatable, Sendable {
    let exifOriginalDate: Date?
    let exifDigitizedDate: Date?
    let hasCameraMakerNote: Bool
}

nonisolated enum PhotoCaptureRejectionReason: Equatable, Sendable {
    case implausibleLibraryAdditionDate
    case missingCameraMakerNote
    case missingTimezoneAwareEXIFDates
    case inconsistentEXIFDates
    case creationDateMismatch
}

@ModelActor
actor PhotoSignalIngestor {
    enum IngestMode {
        case auto
        case manualFullScan
        case sequenced
    }

    private var resolver: CountryResolving?
    private var recoveryStore: LedgerRecomputeRecoveryStore = .shared
    private var provenanceDefaults: UserDefaults = AppConfig.sharedDefaults
    internal var saveContextOverride: (@Sendable () throws -> Void)?

    nonisolated static let maximumCaptureToLibraryDelay: TimeInterval = 10 * 60
    nonisolated static let timestampTolerance: TimeInterval = 2 * 60
    private nonisolated static let provenancePolicyDefaultsKey =
        "borderLog.photoCaptureProvenancePolicyVersion"
    private nonisolated static let provenancePolicyVersion = 1

    struct IngestQueryConfig {
        let startDate: Date
        let endDate: Date?
        let sortAscending: Bool
    }

    private struct ProvenanceRebuild {
        let affectedDayKeys: Set<String>
        let earliestSignalDate: Date?
    }

    init(
        modelContainer: ModelContainer,
        resolver: CountryResolving,
        recoveryStore: LedgerRecomputeRecoveryStore = .shared,
        provenanceDefaults: UserDefaults = AppConfig.sharedDefaults
    ) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.resolver = resolver
        self.recoveryStore = recoveryStore
        self.provenanceDefaults = provenanceDefaults
    }

    func ingest(mode: IngestMode) async throws -> Int {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return 0
        }

        await DiagnosticsStore.shared.recordPhotoScanStarted()
        do {
            return try await ingestAuthorised(mode: mode)
        } catch {
            await DiagnosticsStore.shared.recordPhotoScanFailure()
            throw error
        }
    }

    private func ingestAuthorised(mode: IngestMode) async throws -> Int {
        var didBeginScan = false
        defer {
            if didBeginScan {
                Task { @MainActor in
                    InferenceActivity.shared.endPhotoScan()
                }
            }
        }

        let state = fetchOrCreateState()
        let requiresProvenanceRebuild = provenanceDefaults.integer(
            forKey: Self.provenancePolicyDefaultsKey
        ) < Self.provenancePolicyVersion
        let provenanceRebuild = try prepareForProvenanceRebuildIfNeeded(
            state: state,
            required: requiresProvenanceRebuild
        )

        let calendar = Calendar.current
        let now = Date()

        let effectiveMode: IngestMode
        if requiresProvenanceRebuild {
            switch mode {
            case .manualFullScan:
                effectiveMode = .manualFullScan
            case .auto, .sequenced:
                effectiveMode = .sequenced
            }
        } else {
            effectiveMode = mode
        }
        let baseConfig = Self.ingestQueryConfig(
            mode: effectiveMode,
            state: state,
            now: now,
            calendar: calendar
        )
        let config = Self.expandingForProvenanceRebuild(
            baseConfig,
            earliestSignalDate: provenanceRebuild.earliestSignalDate
        )

        let options = PHFetchOptions()
        options.includeAssetSourceTypes = [.typeUserLibrary]
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
        var existingAssetHashes: Set<String> = requiresProvenanceRebuild
            ? []
            : try fetchExistingAssetIdHashes(config: config)

        if assetCount > 0 {
            await MainActor.run {
                InferenceActivity.shared.beginPhotoScan(totalAssets: assetCount)
            }
            didBeginScan = true
        }

        var processed = 0
        var touchedDayKeys = provenanceRebuild.affectedDayKeys
        var rejectedMissingCreationDate = 0
        var rejectedMissingLocation = 0
        var rejectedDuplicateAsset = 0
        var rejectedUnverifiedCapture = 0
        var unresolvedCountrySignals = 0
        let saveEvery = 25
        let progressUpdateEvery = 25

        if assetCount > 0 {
            for index in 0..<assetCount {
                let asset = assets.object(at: index)
                let scannedAssets = index + 1
                if scannedAssets % progressUpdateEvery == 0 || scannedAssets == assetCount {
                    await MainActor.run {
                        InferenceActivity.shared.updatePhotoScanProgress(scannedAssets: scannedAssets)
                    }
                }
                guard let creationDate = asset.creationDate else {
                    rejectedMissingCreationDate += 1
                    continue
                }

                let assetIdHash = Self.hashAssetId(asset.localIdentifier)
                Self.applyScannedAssetCheckpoint(state: state, creationDate: creationDate)

                guard let location = asset.location else {
                    rejectedMissingLocation += 1
                    continue
                }

                if existingAssetHashes.contains(assetIdHash) {
                    rejectedDuplicateAsset += 1
                    continue
                }

                guard !asset.mediaSubtypes.contains(.photoScreenshot),
                      Self.hasPlausibleLibraryAdditionTiming(
                          creationDate: creationDate,
                          addedDate: asset.addedDate
                      ) else {
                    rejectedUnverifiedCapture += 1
                    continue
                }

                guard let captureMetadata = await Self.loadCaptureMetadata(for: asset),
                      Self.captureRejectionReason(
                          creationDate: creationDate,
                          addedDate: asset.addedDate,
                          metadata: captureMetadata
                      ) == nil else {
                    rejectedUnverifiedCapture += 1
                    continue
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
                    .flatMap {
                        CountryResolution.normalized(
                            countryCode: $0.countryCode,
                            countryName: $0.countryName,
                            timeZone: $0.timeZone
                        )
                    }
                if resolution == nil {
                    unresolvedCountrySignals += 1
                }
                let timeZone = resolution?.timeZone ?? TimeZone.current
                let dayKey = DayKey.make(from: creationDate, timeZone: timeZone)

                let signal = PhotoSignal(
                    timestamp: creationDate,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    assetIdHash: assetIdHash,
                    timeZoneId: timeZone.identifier,
                    dayKey: dayKey,
                    countryCode: resolution?.countryCode,
                    countryName: resolution?.countryName
                )
                modelContext.insert(signal)
                existingAssetHashes.insert(assetIdHash)
                touchedDayKeys.insert(dayKey)

                Self.applyImportedAssetCheckpoint(
                    state: state,
                    assetIdHash: assetIdHash,
                    importedAt: Date()
                )
                processed += 1

                if processed % saveEvery == 0, modelContext.hasChanges {
                    recoveryStore.markDirty(dayKeys: touchedDayKeys)
                    try saveContextIfNeeded()
                }
            }
        }

        if effectiveMode == .sequenced || effectiveMode == .manualFullScan {
            state.fullScanCompleted = true
            state.lastFullScanAt = now
        }

        // Persist the recovery checkpoint before committing the corresponding source rows.
        // A failed save may leave an unnecessary dirty key, which is safe; the inverse would
        // leave a committed photo permanently absent from the derived ledger.
        recoveryStore.markDirty(dayKeys: touchedDayKeys)
        try saveContextIfNeeded()

        // The scan itself is complete once its source rows and checkpoint are durable. Record
        // these counts before recompute so a downstream ledger failure does not erase useful
        // scan/rejection diagnostics; that failure is recorded separately by the outer catch.
        await DiagnosticsStore.shared.recordPhotoScanCompleted(
            assetsScanned: assetCount,
            signalsImported: processed,
            rejectedMissingCreationDate: rejectedMissingCreationDate,
            rejectedMissingLocation: rejectedMissingLocation,
            rejectedDuplicateAsset: rejectedDuplicateAsset,
            rejectedUnverifiedCapture: rejectedUnverifiedCapture,
            unresolvedCountrySignals: unresolvedCountrySignals
        )

        if !touchedDayKeys.isEmpty {
            let recomputeService = LedgerRecomputeService(modelContainer: modelContainer)
            await recomputeService.setRecoveryStore(recoveryStore)
            try await recomputeService.recompute(dayKeys: Array(touchedDayKeys))
        }

        if requiresProvenanceRebuild {
            provenanceDefaults.set(
                Self.provenancePolicyVersion,
                forKey: Self.provenancePolicyDefaultsKey
            )
        }

        return processed
    }

    nonisolated static func hasPlausibleLibraryAdditionTiming(
        creationDate: Date,
        addedDate: Date
    ) -> Bool {
        let delay = addedDate.timeIntervalSince(creationDate)
        return delay >= -timestampTolerance && delay <= maximumCaptureToLibraryDelay
    }

    nonisolated static func captureRejectionReason(
        creationDate: Date,
        addedDate: Date,
        metadata: PhotoCaptureMetadata
    ) -> PhotoCaptureRejectionReason? {
        // This is deliberately a fail-closed provenance heuristic, not proof of ownership.
        // An original received immediately after capture can still retain matching metadata.
        guard hasPlausibleLibraryAdditionTiming(
            creationDate: creationDate,
            addedDate: addedDate
        ) else {
            return .implausibleLibraryAdditionDate
        }
        guard metadata.hasCameraMakerNote else {
            return .missingCameraMakerNote
        }
        guard let originalDate = metadata.exifOriginalDate,
              let digitizedDate = metadata.exifDigitizedDate else {
            return .missingTimezoneAwareEXIFDates
        }
        guard abs(digitizedDate.timeIntervalSince(originalDate)) <= timestampTolerance else {
            return .inconsistentEXIFDates
        }
        guard abs(creationDate.timeIntervalSince(originalDate)) <= timestampTolerance else {
            return .creationDateMismatch
        }
        let additionDelay = addedDate.timeIntervalSince(originalDate)
        guard additionDelay >= -timestampTolerance,
              additionDelay <= maximumCaptureToLibraryDelay else {
            return .implausibleLibraryAdditionDate
        }
        return nil
    }

    private nonisolated static func loadCaptureMetadata(for asset: PHAsset) async -> PhotoCaptureMetadata? {
        let options = PHImageRequestOptions()
        options.version = .original
        options.deliveryMode = .highQualityFormat
        // Do not turn an automatic historical scan into an implicit iCloud-original download.
        // Assets whose original metadata is not local remain unverified and are ignored.
        options.isNetworkAccessAllowed = false

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, info in
                if info?[PHImageResultIsDegradedKey] as? Bool == true {
                    return
                }
                continuation.resume(returning: data.flatMap(Self.captureMetadata(from:)))
            }
        }
    }

    private nonisolated static func captureMetadata(from imageData: Data) -> PhotoCaptureMetadata? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] else {
            return nil
        }

        let makerDictionaries: [CFString] = [
            kCGImagePropertyMakerAppleDictionary,
            kCGImagePropertyMakerCanonDictionary,
            kCGImagePropertyMakerNikonDictionary,
            kCGImagePropertyMakerMinoltaDictionary,
            kCGImagePropertyMakerFujiDictionary,
            kCGImagePropertyMakerOlympusDictionary,
            kCGImagePropertyMakerPentaxDictionary
        ]
        let hasMakerDictionary = makerDictionaries.contains { key in
            guard let dictionary = properties[key] as? [AnyHashable: Any] else { return false }
            return !dictionary.isEmpty
        }
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let cameraMake = (tiff?[kCGImagePropertyTIFFMake] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cameraModel = (tiff?[kCGImagePropertyTIFFModel] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasGenericMakerNote =
            (exif[kCGImagePropertyExifMakerNote] as? Data)?.isEmpty == false &&
            cameraMake?.isEmpty == false &&
            cameraModel?.isEmpty == false

        return PhotoCaptureMetadata(
            exifOriginalDate: parseEXIFDate(
                value: exif[kCGImagePropertyExifDateTimeOriginal],
                offset: exif[kCGImagePropertyExifOffsetTimeOriginal]
            ),
            exifDigitizedDate: parseEXIFDate(
                value: exif[kCGImagePropertyExifDateTimeDigitized],
                offset: exif[kCGImagePropertyExifOffsetTimeDigitized]
            ),
            hasCameraMakerNote: hasMakerDictionary || hasGenericMakerNote
        )
    }

    nonisolated static func parseEXIFDate(value: Any?, offset: Any?) -> Date? {
        guard let value = value as? String,
              let offset = offset as? String else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ssXXXXX"
        formatter.isLenient = false
        return formatter.date(from: value + offset)
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
                // PhotoKit timestamps are not guaranteed to be unique and assets can arrive
                // slightly out of order after iCloud synchronisation. Re-scan a bounded overlap;
                // asset hashes make this idempotent while keeping the post-bootstrap scan small.
                return IngestQueryConfig(
                    startDate: lastDate.addingTimeInterval(-24 * 60 * 60),
                    endDate: nil,
                    sortAscending: true
                )
            }
            let startDate = calendar.date(byAdding: .month, value: -12, to: now) ?? now
            return IngestQueryConfig(startDate: startDate, endDate: nil, sortAscending: true)
        }
    }

    nonisolated static func expandingForProvenanceRebuild(
        _ config: IngestQueryConfig,
        earliestSignalDate: Date?
    ) -> IngestQueryConfig {
        guard let earliestSignalDate, earliestSignalDate < config.startDate else {
            return config
        }
        return IngestQueryConfig(
            startDate: earliestSignalDate,
            endDate: config.endDate,
            sortAscending: config.sortAscending
        )
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

    private func prepareForProvenanceRebuildIfNeeded(
        state: PhotoIngestState,
        required: Bool
    ) throws -> ProvenanceRebuild {
        guard required else {
            return ProvenanceRebuild(affectedDayKeys: [], earliestSignalDate: nil)
        }

        let existingSignals = try modelContext.fetch(FetchDescriptor<PhotoSignal>())
        let affectedDayKeys = Set(existingSignals.map(\.dayKey))
        let earliestSignalDate = existingSignals.lazy.map(\.timestamp).min()
        for signal in existingSignals {
            modelContext.delete(signal)
        }
        state.lastIngestedAt = nil
        state.lastAssetCreationDate = nil
        state.lastAssetIdHash = nil
        state.fullScanCompleted = false
        state.lastFullScanAt = nil
        return ProvenanceRebuild(
            affectedDayKeys: affectedDayKeys,
            earliestSignalDate: earliestSignalDate
        )
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
        return Set(try modelContext.fetch(descriptor).lazy.map(\.assetIdHash))
    }

    internal func saveContextIfNeeded() throws {
        guard modelContext.hasChanges else { return }
        if let saveContextOverride {
            try saveContextOverride()
        } else {
            try modelContext.save()
        }
    }

    nonisolated static func applyScannedAssetCheckpoint(
        state: PhotoIngestState,
        creationDate: Date
    ) {
        if let existingDate = state.lastAssetCreationDate, existingDate >= creationDate {
            return
        }
        state.lastAssetCreationDate = creationDate
    }

    nonisolated static func applyImportedAssetCheckpoint(
        state: PhotoIngestState,
        assetIdHash: String,
        importedAt: Date = Date()
    ) {
        state.lastAssetIdHash = assetIdHash
        state.lastIngestedAt = importedAt
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

    internal func prepareForProvenanceRebuildForTesting() throws -> Set<String> {
        let state = fetchOrCreateState()
        return try prepareForProvenanceRebuildIfNeeded(
            state: state,
            required: true
        ).affectedDayKeys
    }

    private static func hashAssetId(_ identifier: String) -> String {
        let data = Data(identifier.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
