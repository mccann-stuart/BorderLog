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
final class LocationCaptureCoordinator {
    private var singleContinuations: [CheckedContinuation<CLLocation?, Never>] = []
    private var batchContinuations: [CheckedContinuation<[CLLocation], Never>] = []
    private var batchLocations: [CLLocation] = []
    private var batchTargetCount: Int = 0
    private var batchMaxSampleAge: TimeInterval = 0
    private var batchTimeoutTask: Task<Void, Never>?

    private let requestSingleLocation: () -> Void
    private let startBatchLocationUpdates: () -> Void
    private let stopBatchLocationUpdates: () -> Void
    private let beginLocationBatchActivity: () -> Void
    private let endLocationBatchActivity: () -> Void

    init(
        requestSingleLocation: @escaping () -> Void = {},
        startBatchLocationUpdates: @escaping () -> Void = {},
        stopBatchLocationUpdates: @escaping () -> Void = {},
        beginLocationBatchActivity: @escaping () -> Void = {},
        endLocationBatchActivity: @escaping () -> Void = {}
    ) {
        self.requestSingleLocation = requestSingleLocation
        self.startBatchLocationUpdates = startBatchLocationUpdates
        self.stopBatchLocationUpdates = stopBatchLocationUpdates
        self.beginLocationBatchActivity = beginLocationBatchActivity
        self.endLocationBatchActivity = endLocationBatchActivity
    }

    var pendingWaiterCount: Int {
        singleContinuations.count + batchContinuations.count
    }

    var isBatchActive: Bool {
        !batchContinuations.isEmpty
    }

    func captureLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            let shouldRequest = singleContinuations.isEmpty && !isBatchActive
            singleContinuations.append(continuation)
            if shouldRequest {
                requestSingleLocation()
            }
        }
    }

    func captureLocations(
        maxSamples: Int,
        maxDuration: TimeInterval,
        maxSampleAge: TimeInterval
    ) async -> [CLLocation] {
        await withCheckedContinuation { continuation in
            let shouldStartBatch = !isBatchActive
            batchContinuations.append(continuation)

            if shouldStartBatch {
                batchLocations = []
                batchTargetCount = max(1, maxSamples)
                batchMaxSampleAge = maxSampleAge
                beginLocationBatchActivity()
                startBatchLocationUpdates()
                scheduleBatchTimeout(maxDuration: maxDuration)
            } else {
                batchTargetCount = max(batchTargetCount, max(1, maxSamples))
                batchMaxSampleAge = min(batchMaxSampleAge, maxSampleAge)
            }
        }
    }

    func receive(locations: [CLLocation], now: Date = Date()) {
        if isBatchActive {
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
            return
        }

        resumeSingleContinuations(returning: locations.first)
    }

    func fail() {
        if isBatchActive {
            finishBatchCapture()
        } else {
            resumeSingleContinuations(returning: nil)
        }
    }

    func expireBatchForTesting() {
        finishBatchCapture()
    }

    private func scheduleBatchTimeout(maxDuration: TimeInterval) {
        batchTimeoutTask?.cancel()
        batchTimeoutTask = Task { @MainActor in
            let duration = max(0, maxDuration)
            let nanos = UInt64(duration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            finishBatchCapture()
        }
    }

    private func finishBatchCapture() {
        guard isBatchActive else { return }

        endLocationBatchActivity()
        stopBatchLocationUpdates()
        batchTimeoutTask?.cancel()
        batchTimeoutTask = nil

        let locations = batchLocations
        let batchWaiters = batchContinuations
        batchLocations = []
        batchContinuations = []
        batchTargetCount = 0
        batchMaxSampleAge = 0

        for continuation in batchWaiters {
            continuation.resume(returning: locations)
        }
        resumeSingleContinuations(returning: locations.first)
    }

    private func resumeSingleContinuations(returning location: CLLocation?) {
        guard !singleContinuations.isEmpty else { return }
        let waiters = singleContinuations
        singleContinuations = []
        for continuation in waiters {
            continuation.resume(returning: location)
        }
    }
}

@MainActor
final class LocationSampleService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "LocationSampleService")
    private var previousBatchAccuracy: CLLocationAccuracy?
    private lazy var captureCoordinator = LocationCaptureCoordinator(
        requestSingleLocation: { [weak self] in
            self?.manager.requestLocation()
        },
        startBatchLocationUpdates: { [weak self] in
            guard let self else { return }
            previousBatchAccuracy = manager.desiredAccuracy
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.startUpdatingLocation()
        },
        stopBatchLocationUpdates: { [weak self] in
            guard let self else { return }
            manager.stopUpdatingLocation()
            if let previousBatchAccuracy {
                manager.desiredAccuracy = previousBatchAccuracy
                self.previousBatchAccuracy = nil
            }
        },
        beginLocationBatchActivity: {
            InferenceActivity.shared.beginLocationBatch()
        },
        endLocationBatchActivity: {
            InferenceActivity.shared.endLocationBatch()
        }
    )

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
        await captureCoordinator.captureLocation()
    }

    private func captureLocations(
        maxSamples: Int,
        maxDuration: TimeInterval,
        maxSampleAge: TimeInterval
    ) async -> [CLLocation] {
        await captureCoordinator.captureLocations(
            maxSamples: maxSamples,
            maxDuration: maxDuration,
            maxSampleAge: maxSampleAge
        )
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        captureCoordinator.receive(locations: locations)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        captureCoordinator.fail()
    }
}
