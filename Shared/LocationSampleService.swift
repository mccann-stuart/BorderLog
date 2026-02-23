//
//  LocationSampleService.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import CoreLocation
import SwiftData

@MainActor
final class LocationSampleService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
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

    func captureAndStore(
        source: LocationSampleSource,
        modelContext: ModelContext,
        resolver: CountryResolving? = nil
    ) async -> LocationSample? {
        let resolver = resolver ?? CLGeocoderCountryResolver()
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
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
            timeZoneId: resolution?.timeZone?.identifier,
            dayKey: dayKey,
            countryCode: resolution?.countryCode,
            countryName: resolution?.countryName
        )
        modelContext.insert(sample)

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
    ) async -> LocationSample? {
        let resolver = resolver ?? CLGeocoderCountryResolver()
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
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

        let selectedLocations = locations
            .sorted { $0.horizontalAccuracy < $1.horizontalAccuracy }
            .prefix(targetSamples)

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
                timeZoneId: resolution?.timeZone?.identifier,
                dayKey: dayKey,
                countryCode: resolution?.countryCode,
                countryName: resolution?.countryName
            )
            modelContext.insert(sample)
            storedSamples.append(sample)
        }

        if !dayKeys.isEmpty {
            let container = modelContext.container
            let recomputeService = LedgerRecomputeService(modelContainer: container)
            await recomputeService.recompute(dayKeys: Array(dayKeys))
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
