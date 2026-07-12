//
//  PhotoSignalGeocodeRetryService.swift
//  Learn
//
//  Created by Codex on 11/07/2026.
//

import CoreLocation
import Foundation
@preconcurrency import SwiftData

nonisolated struct PhotoSignalGeocodeRetryStats: Equatable, Sendable {
    let candidateSignals: Int
    let lookupRequests: Int
    let resolvedSignals: Int
    let unresolvedSignals: Int
    let errors: Int
}

nonisolated struct PhotoSignalGeocodeRetryResult: Equatable, Sendable {
    let touchedDayKeys: Set<String>
    let stats: PhotoSignalGeocodeRetryStats
}

/// Retries country resolution for already-imported photo signals without changing the data schema.
/// The caller owns orchestration and ledger recomputation for the returned day keys.
@ModelActor
actor PhotoSignalGeocodeRetryService {
    private struct CoordinateKey: Hashable {
        let latitude: Double
        let longitude: Double
    }

    private var resolver: CountryResolving?
    private var recoveryStore: LedgerRecomputeRecoveryStore = .shared
    private var diagnosticsStore: DiagnosticsStore = .shared

    init(
        modelContainer: ModelContainer,
        resolver: CountryResolving,
        recoveryStore: LedgerRecomputeRecoveryStore = .shared,
        diagnosticsStore: DiagnosticsStore = .shared
    ) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.resolver = resolver
        self.recoveryStore = recoveryStore
        self.diagnosticsStore = diagnosticsStore
    }

    func retryUnresolved() async throws -> PhotoSignalGeocodeRetryResult {
        do {
            return try await performRetry()
        } catch {
            await diagnosticsStore.recordPhotoGeocodeRetryFailure()
            throw error
        }
    }

    private func performRetry() async throws -> PhotoSignalGeocodeRetryResult {
        let allSignals = try modelContext.fetch(FetchDescriptor<PhotoSignal>())
        let candidates = allSignals.filter(Self.isCountryUnresolved)
        let signalsByCoordinate = Dictionary(
            grouping: candidates,
            by: { CoordinateKey(latitude: $0.latitude, longitude: $0.longitude) }
        )
        let retryResolver = await activeResolver()

        var touchedDayKeys = Set<String>()
        var lookupRequests = 0
        var resolvedSignals = 0
        var unresolvedSignals = 0

        for signals in signalsByCoordinate.values {
            guard let representative = signals.first else { continue }
            lookupRequests += 1

            let location = CLLocation(
                latitude: representative.latitude,
                longitude: representative.longitude
            )
            let resolution = await retryResolver.resolveCountry(for: location)
                .flatMap {
                    CountryResolution.normalized(
                        countryCode: $0.countryCode,
                        countryName: $0.countryName,
                        timeZone: $0.timeZone
                    )
                }

            guard let resolution else {
                unresolvedSignals += signals.count
                continue
            }

            for signal in signals {
                let previousDayKey = signal.dayKey
                let resolvedTimeZone = resolution.timeZone
                    ?? signal.timeZoneId.flatMap(TimeZone.init(identifier:))
                    ?? .current
                let resolvedDayKey = DayKey.make(from: signal.timestamp, timeZone: resolvedTimeZone)

                signal.countryCode = resolution.countryCode
                signal.countryName = resolution.countryName
                signal.timeZoneId = resolvedTimeZone.identifier
                signal.dayKey = resolvedDayKey

                touchedDayKeys.insert(previousDayKey)
                touchedDayKeys.insert(resolvedDayKey)
                resolvedSignals += 1
            }
        }

        if modelContext.hasChanges {
            // Record both the old and corrected day identities before saving source changes.
            // An unnecessary dirty key is safe after a failed save; an untracked committed
            // change could otherwise remain absent from the derived ledger indefinitely.
            recoveryStore.markDirty(dayKeys: touchedDayKeys)
            try modelContext.save()
        }

        let result = PhotoSignalGeocodeRetryResult(
            touchedDayKeys: touchedDayKeys,
            stats: PhotoSignalGeocodeRetryStats(
                candidateSignals: candidates.count,
                lookupRequests: lookupRequests,
                resolvedSignals: resolvedSignals,
                unresolvedSignals: unresolvedSignals,
                errors: 0
            )
        )
        await diagnosticsStore.recordPhotoGeocodeRetry(
            candidateSignals: result.stats.candidateSignals,
            lookupRequests: result.stats.lookupRequests,
            resolvedSignals: result.stats.resolvedSignals,
            unresolvedSignals: result.stats.unresolvedSignals
        )
        return result
    }

    private func activeResolver() async -> CountryResolving {
        if let resolver {
            return resolver
        }
        let resolver = await MainActor.run { CLGeocoderCountryResolver() }
        self.resolver = resolver
        return resolver
    }

    private nonisolated static func isCountryUnresolved(_ signal: PhotoSignal) -> Bool {
        let countryCode = signal.countryCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        let countryName = signal.countryName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (countryCode?.isEmpty ?? true) && (countryName?.isEmpty ?? true)
    }
}
