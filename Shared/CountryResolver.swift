//
//  CountryResolver.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import CoreLocation
import MapKit

struct CountryResolution: Sendable {
    let countryCode: String?
    let countryName: String?
    let timeZone: TimeZone?
}

protocol CountryResolving {
    func resolveCountry(for location: CLLocation) async -> CountryResolution?
}

actor CountryResolutionCache {
    private var cache: [String: CountryResolution] = [:]

    func value(for key: String) -> CountryResolution? {
        cache[key]
    }

    func set(_ value: CountryResolution, for key: String) {
        cache[key] = value
    }
}

actor GeocodeCoordinator {
    static let shared = GeocodeCoordinator()

    private let maxRequests = 45
    private let windowSeconds: TimeInterval = 60
    private var requestTimes: [Date] = []
    private var inFlight: [String: Task<CountryResolution?, Never>] = [:]
    private var cache: [String: CountryResolution] = [:]

    func resolve(location: CLLocation) async -> CountryResolution? {
        let key = cacheKey(for: location)
        if let cached = cache[key] {
            return cached
        }

        if let task = inFlight[key] {
            return await task.value
        }

        let task = Task { [self] in
            defer {
                Task { await self.clearInFlight(for: key) }
            }

            await self.waitForPermit()

            do {
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    return nil
                }
                let mapItems = try await request.mapItems
                let mapItem = mapItems.first
                let addressRepresentations = mapItem?.addressRepresentations
                let resolution = CountryResolution(
                    countryCode: addressRepresentations?.region?.identifier,
                    countryName: addressRepresentations?.regionName,
                    timeZone: mapItem?.timeZone
                )
                if resolution.countryCode != nil || resolution.countryName != nil {
                    await self.store(resolution, for: key)
                }
                return resolution
            } catch {
                return nil
            }
        }

        inFlight[key] = task
        return await task.value
    }

    private func waitForPermit() async {
        while true {
            let now = Date()
            pruneRequests(now: now)
            if requestTimes.count < maxRequests {
                requestTimes.append(now)
                return
            }

            let earliest = requestTimes.first ?? now
            let nextAvailable = earliest.addingTimeInterval(windowSeconds)
            let delay = max(0, nextAvailable.timeIntervalSince(now))
            let nanos = UInt64((delay + 0.01) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
        }
    }

    private func pruneRequests(now: Date) {
        requestTimes.removeAll { now.timeIntervalSince($0) >= windowSeconds }
    }

    private func clearInFlight(for key: String) {
        inFlight[key] = nil
    }

    private func store(_ resolution: CountryResolution, for key: String) {
        cache[key] = resolution
    }

    private func cacheKey(for location: CLLocation) -> String {
        let lat = String(format: "%.3f", location.coordinate.latitude)
        let lon = String(format: "%.3f", location.coordinate.longitude)
        return "\(lat),\(lon)"
    }
}

final class CLGeocoderCountryResolver: CountryResolving {

    func resolveCountry(for location: CLLocation) async -> CountryResolution? {
        await GeocodeCoordinator.shared.resolve(location: location)
    }
}
