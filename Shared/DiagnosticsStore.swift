//
//  DiagnosticsStore.swift
//  Learn
//
//  Created by Codex on 11/07/2026.
//

import Foundation

nonisolated struct PhotoScanDiagnostics: Codable, Equatable, Sendable {
    var runsStarted: Int = 0
    var runsCompleted: Int = 0
    var runsFailed: Int = 0
    var assetsScanned: Int = 0
    var signalsImported: Int = 0
    var assetsRejected: Int = 0
    var rejectedMissingCreationDate: Int = 0
    var rejectedMissingLocation: Int = 0
    var rejectedDuplicateAsset: Int = 0
    var rejectedUnverifiedCapture: Int?
    var unresolvedCountrySignals: Int = 0
    var errors: Int = 0
    var lastStartedAt: Date?
    var lastCompletedAt: Date?
    var lastErrorAt: Date?
}

nonisolated struct PhotoGeocodeRetryDiagnostics: Codable, Equatable, Sendable {
    var runsCompleted: Int = 0
    var runsFailed: Int = 0
    var candidateSignals: Int = 0
    var lookupRequests: Int = 0
    var resolvedSignals: Int = 0
    var unresolvedSignals: Int = 0
    var errors: Int = 0
    var lastCompletedAt: Date?
    var lastErrorAt: Date?
}

nonisolated struct DiagnosticsSnapshot: Codable, Equatable, Sendable {
    var photoScanning = PhotoScanDiagnostics()
    var photoGeocodeRetries = PhotoGeocodeRetryDiagnostics()
    var lastSuccessfulRecomputeAt: Date?
}

/// Persists aggregate operational diagnostics without adding fields to the SwiftData schema.
/// Only counters and timestamps are stored; errors, coordinates, identifiers, and user data are not.
actor DiagnosticsStore {
    nonisolated static let storageKey = "borderLog.operationalDiagnostics.v1"
    static let shared = DiagnosticsStore(defaults: AppConfig.sharedDefaults)

    private let defaults: UserDefaults
    private let storageKey: String
    private var state: DiagnosticsSnapshot

    init(
        defaults: UserDefaults,
        storageKey: String = DiagnosticsStore.storageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(DiagnosticsSnapshot.self, from: data) {
            state = decoded
        } else {
            state = DiagnosticsSnapshot()
        }
    }

    func snapshot() -> DiagnosticsSnapshot {
        state
    }

    func recordPhotoScanStarted(at date: Date = Date()) {
        state.photoScanning.runsStarted += 1
        state.photoScanning.lastStartedAt = date
        persist()
    }

    func recordPhotoScanCompleted(
        assetsScanned: Int,
        signalsImported: Int,
        rejectedMissingCreationDate: Int,
        rejectedMissingLocation: Int,
        rejectedDuplicateAsset: Int,
        rejectedUnverifiedCapture: Int,
        unresolvedCountrySignals: Int,
        at date: Date = Date()
    ) {
        let missingCreationDate = max(0, rejectedMissingCreationDate)
        let missingLocation = max(0, rejectedMissingLocation)
        let duplicateAsset = max(0, rejectedDuplicateAsset)
        let unverifiedCapture = max(0, rejectedUnverifiedCapture)

        state.photoScanning.runsCompleted += 1
        state.photoScanning.assetsScanned += max(0, assetsScanned)
        state.photoScanning.signalsImported += max(0, signalsImported)
        state.photoScanning.rejectedMissingCreationDate += missingCreationDate
        state.photoScanning.rejectedMissingLocation += missingLocation
        state.photoScanning.rejectedDuplicateAsset += duplicateAsset
        state.photoScanning.rejectedUnverifiedCapture =
            (state.photoScanning.rejectedUnverifiedCapture ?? 0) + unverifiedCapture
        state.photoScanning.assetsRejected +=
            missingCreationDate + missingLocation + duplicateAsset + unverifiedCapture
        state.photoScanning.unresolvedCountrySignals += max(0, unresolvedCountrySignals)
        state.photoScanning.lastCompletedAt = date
        persist()
    }

    func recordPhotoScanFailure(errorCount: Int = 1, at date: Date = Date()) {
        state.photoScanning.runsFailed += 1
        state.photoScanning.errors += max(1, errorCount)
        state.photoScanning.lastErrorAt = date
        persist()
    }

    func recordPhotoGeocodeRetry(
        candidateSignals: Int,
        lookupRequests: Int,
        resolvedSignals: Int,
        unresolvedSignals: Int,
        at date: Date = Date()
    ) {
        state.photoGeocodeRetries.runsCompleted += 1
        state.photoGeocodeRetries.candidateSignals += max(0, candidateSignals)
        state.photoGeocodeRetries.lookupRequests += max(0, lookupRequests)
        state.photoGeocodeRetries.resolvedSignals += max(0, resolvedSignals)
        state.photoGeocodeRetries.unresolvedSignals += max(0, unresolvedSignals)
        state.photoGeocodeRetries.lastCompletedAt = date
        persist()
    }

    func recordPhotoGeocodeRetryFailure(errorCount: Int = 1, at date: Date = Date()) {
        state.photoGeocodeRetries.runsFailed += 1
        state.photoGeocodeRetries.errors += max(1, errorCount)
        state.photoGeocodeRetries.lastErrorAt = date
        persist()
    }

    func recordSuccessfulRecompute(at date: Date = Date()) {
        state.lastSuccessfulRecomputeAt = date
        persist()
    }

    func reset() {
        state = DiagnosticsSnapshot()
        defaults.removeObject(forKey: storageKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

nonisolated enum BuildCommitMetadata {
    static let unavailable = "unavailable"

    static func resolvedCommit(
        infoDictionaryValue: Any?,
        environmentValue: String?
    ) -> String {
        for candidate in [infoDictionaryValue as? String, environmentValue] {
            guard let candidate else { continue }
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (7...64).contains(trimmed.count),
                  trimmed.allSatisfy({ $0.isHexDigit }) else {
                continue
            }
            return trimmed.lowercased()
        }
        return unavailable
    }
}
