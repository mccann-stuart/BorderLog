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
    private var continuation: CheckedContinuation<CLLocation?, Never>?

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
        resolver: CountryResolving = CLGeocoderCountryResolver()
    ) async -> LocationSample? {
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

        await LedgerRecomputeService.recompute(dayKeys: [dayKey], modelContext: modelContext)

        return sample
    }

    private func captureLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            continuation?.resume(returning: location)
        } else {
            continuation?.resume(returning: nil)
        }
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}
