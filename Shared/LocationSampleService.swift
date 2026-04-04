//
//  LocationSampleService.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import CoreLocation
import SwiftData
import os

@MainActor
final class LocationSampleService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "LocationSampleService")
    private var continuations: [CheckedContinuation<CLLocation?, Never>] = []
    private var batchContinuation: CheckedContinuation<[CLLocation], Never>?
    private var batchLocations: [CLLocation] = []
    private var batchTargetCount: Int = 0
    private var batchMaxSampleAge: TimeInterval = 0
    private var batchTimeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAuthorizationIfNeeded() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated static func isCaptureAuthorized(
        source: LocationSampleSource,
        status: CLAuthorizationStatus,
        isAuthorizedForWidgetUpdates: Bool
    ) -> Bool {
        let hasLocationAuthorization = status == .authorizedWhenInUse || status == .authorizedAlways
        guard hasLocationAuthorization else { return false }

        switch source {
        case .app:
            return true
        case .widget:
            return isAuthorizedForWidgetUpdates
        }
    }

    func captureAndStore(
        source: LocationSampleSource,
        modelContext: ModelContext,
        resolver: CountryResolving? = nil
    ) async throws -> LocationSample? {
        let resolver = resolver ?? CLGeocoderCountryResolver()
        guard Self.isCaptureAuthorized(
            source: source,
            status: manager.authorizationStatus,
            isAuthorizedForWidgetUpdates: manager.isAuthorizedForWidgetUpdates
        ) else {
            return nil
        }

        guard let location = await captureLocation() else {
            return nil
        }

        let resolution = await resolver.resolveCountry(for: location)
        let timeZone = resolution?.timeZone ?? TimeZone.current
        let dayKey = DayKey.make(from: location.timestamp, timeZone: timeZone)

        let sample = LocationSample(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracyMeters: location.horizontalAccuracy,
            source: source,
            timeZoneId: timeZone.identifier,
            dayKey: dayKey,
            countryCode: resolution?.countryCode,
            countryName: resolution?.countryName
        )
        
        if source == .widget {
            let pending = PendingLocationSnapshot(
                timestamp: sample.timestamp,
                latitude: sample.latitude,
                longitude: sample.longitude,
                accuracyMeters: sample.accuracyMeters,
                sourceRaw: sample.sourceRaw,
                timeZoneId: sample.timeZoneId,
                dayKey: sample.dayKey,
                countryCode: sample.countryCode,
                countryName: sample.countryName
            )
            PendingLocationSnapshot.enqueue(pending, in: AppConfig.sharedDefaults)
            return sample
        }

        modelContext.insert(sample)

        do {
            try modelContext.save()
        } catch {
            Self.logger.error("LocationSampleService save error: \(error, privacy: .private)")
            throw error
        }

        let container = modelContext.container
        let recomputeService = LedgerRecomputeService(modelContainer: container)
        await recomputeService.recompute(dayKeys: [dayKey])

        return sample
    }

    func captureAndStoreBurst(
        source: LocationSampleSource,
        modelContext: ModelContext,
        resolver: CountryResolving? = nil,
        maxSamples: Int = 6,
        maxDuration: TimeInterval = 8,
        maxSampleAge: TimeInterval = 120
    ) async throws -> LocationSample? {
        let resolver = resolver ?? CLGeocoderCountryResolver()
        guard Self.isCaptureAuthorized(
            source: source,
            status: manager.authorizationStatus,
            isAuthorizedForWidgetUpdates: manager.isAuthorizedForWidgetUpdates
        ) else {
            return nil
        }

        let previousAccuracy = manager.desiredAccuracy
        manager.desiredAccuracy = kCLLocationAccuracyBest
        defer { manager.desiredAccuracy = previousAccuracy }

        let targetSamples = max(1, maxSamples)
        let locations = await captureLocations(
            maxSamples: targetSamples,
            maxDuration: maxDuration,
            maxSampleAge: maxSampleAge
        )
        guard !locations.isEmpty else {
            return nil
        }

        let bestLocation = locations.min(by: { $0.horizontalAccuracy < $1.horizontalAccuracy }) ?? locations[0]
        let resolution = await resolver.resolveCountry(for: bestLocation)
        let timeZone = resolution?.timeZone ?? TimeZone.current

        // ⚡ Bolt: Replace O(N log N) sorting + prefix with an O(N) top-K extraction to eliminate ARC thrashing
        var selectedLocations: [CLLocation] = []
        if targetSamples > 0 {
            selectedLocations.reserveCapacity(targetSamples)
            for location in locations {
                if selectedLocations.count < targetSamples {
                    selectedLocations.append(location)
                    if selectedLocations.count == targetSamples {
                        selectedLocations.sort { $0.horizontalAccuracy < $1.horizontalAccuracy }
                    }
                } else if let last = selectedLocations.last, location.horizontalAccuracy < last.horizontalAccuracy {
                    // Find insertion point to keep the top K array sorted
                    if let insertionIndex = selectedLocations.firstIndex(where: { $0.horizontalAccuracy > location.horizontalAccuracy }) {
                        selectedLocations.insert(location, at: insertionIndex)
                        selectedLocations.removeLast()
                    }
                }
            }
            if selectedLocations.count < targetSamples {
                selectedLocations.sort { $0.horizontalAccuracy < $1.horizontalAccuracy }
            }
        }

        var dayKeys = Set<String>()
        var storedSamples: [LocationSample] = []
        storedSamples.reserveCapacity(selectedLocations.count)

        for location in selectedLocations {
            let dayKey = DayKey.make(from: location.timestamp, timeZone: timeZone)
            dayKeys.insert(dayKey)
            let sample = LocationSample(
                timestamp: location.timestamp,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracyMeters: location.horizontalAccuracy,
                source: source,
                timeZoneId: timeZone.identifier,
                dayKey: dayKey,
                countryCode: resolution?.countryCode,
                countryName: resolution?.countryName
            )
            
            if source == .widget {
                let pending = PendingLocationSnapshot(
                    timestamp: sample.timestamp,
                    latitude: sample.latitude,
                    longitude: sample.longitude,
                    accuracyMeters: sample.accuracyMeters,
                    sourceRaw: sample.sourceRaw,
                    timeZoneId: sample.timeZoneId,
                    dayKey: sample.dayKey,
                    countryCode: sample.countryCode,
                    countryName: sample.countryName
                )
                PendingLocationSnapshot.enqueue(pending, in: AppConfig.sharedDefaults)
            } else {
                modelContext.insert(sample)
            }
            storedSamples.append(sample)
        }

        if source != .widget {
            if modelContext.hasChanges {
                do {
                    try modelContext.save()
                } catch {
                    Self.logger.error("LocationSampleService burst save error: \(error, privacy: .private)")
                    throw error
                }
            }

            if !dayKeys.isEmpty {
                let container = modelContext.container
                let recomputeService = LedgerRecomputeService(modelContainer: container)
                await recomputeService.recompute(dayKeys: Array(dayKeys))
            }
        }

        return storedSamples.first
    }

    private func captureLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            let isIdle = continuations.isEmpty && batchContinuation == nil
            continuations.append(continuation)
            if isIdle {
                manager.requestLocation()
            }
        }
    }

    private func captureLocations(
        maxSamples: Int,
        maxDuration: TimeInterval,
        maxSampleAge: TimeInterval
    ) async -> [CLLocation] {
        await withCheckedContinuation { continuation in
            batchContinuation = continuation
            batchLocations = []
            batchTargetCount = maxSamples
            batchMaxSampleAge = maxSampleAge
            InferenceActivity.shared.beginLocationBatch()
            manager.startUpdatingLocation()

            batchTimeoutTask?.cancel()
            batchTimeoutTask = Task { @MainActor in
                let duration = max(0, maxDuration)
                let nanos = UInt64(duration * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                finishBatchCapture()
            }
        }
    }

    private func finishBatchCapture() {
        guard let continuation = batchContinuation else { return }
        InferenceActivity.shared.endLocationBatch()
        manager.stopUpdatingLocation()
        batchTimeoutTask?.cancel()
        batchTimeoutTask = nil
        let locations = batchLocations
        batchLocations = []
        batchContinuation = nil
        continuation.resume(returning: locations)

        if !continuations.isEmpty {
            let bestLocation = locations.first
            for cont in continuations {
                cont.resume(returning: bestLocation)
            }
            continuations.removeAll()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if batchContinuation != nil {
            let now = Date()
            let fresh = locations.filter { location in
                guard location.horizontalAccuracy > 0 else { return false }
                let age = max(0, now.timeIntervalSince(location.timestamp))
                return age <= batchMaxSampleAge
            }
            if !fresh.isEmpty {
                batchLocations.append(contentsOf: fresh)
            }
            if batchLocations.count >= batchTargetCount {
                finishBatchCapture()
            }
        }

        if !continuations.isEmpty {
            let location = locations.first
            for cont in continuations {
                cont.resume(returning: location)
            }
            continuations.removeAll()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if batchContinuation != nil {
            finishBatchCapture()
            return
        }

        for cont in continuations {
            cont.resume(returning: nil)
        }
        continuations.removeAll()
    }
}
