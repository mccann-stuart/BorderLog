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
    private let throttleStore = GeocodeThrottleStore.shared
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

        let task: Task<CountryResolution?, Never> = Task { [self] in
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
                await self.handleThrottleError(error)
                return nil
            }
        }

        inFlight[key] = task
        return await task.value
    }

    private func waitForPermit() async {
        if throttleStore.isAvailable {
            await waitForSharedPermit()
        } else {
            await waitForLocalPermit()
        }
    }

    private func waitForSharedPermit() async {
        var didEnterHold = false
        while true {
            let now = Date()
            let nowInterval = now.timeIntervalSince1970
            var state = throttleStore.loadState()
            var didMutate = false

            if let blockedUntil = state.blockedUntil, blockedUntil > nowInterval {
                if !didEnterHold {
                    await MainActor.run {
                        InferenceActivity.shared.beginGeoLookupHold()
                    }
                    didEnterHold = true
                }
                let delay = blockedUntil - nowInterval
                let nanos = UInt64((delay + 0.01) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                continue
            }

            let beforeCount = state.timestamps.count
            state.timestamps.removeAll { nowInterval - $0 >= windowSeconds }
            if state.timestamps.count != beforeCount {
                didMutate = true
            }

            if let blockedUntil = state.blockedUntil, blockedUntil <= nowInterval {
                state.blockedUntil = nil
                didMutate = true
            }

            if state.timestamps.count < maxRequests {
                state.timestamps.append(nowInterval)
                didMutate = true
                if didMutate {
                    throttleStore.saveState(state)
                }
                if didEnterHold {
                    await MainActor.run {
                        InferenceActivity.shared.endGeoLookupHold()
                    }
                }
                return
            }

            if didMutate {
                throttleStore.saveState(state)
            }

            if !didEnterHold {
                await MainActor.run {
                    InferenceActivity.shared.beginGeoLookupHold()
                }
                didEnterHold = true
            }

            let earliest = state.timestamps.min() ?? nowInterval
            let nextAvailable = earliest + windowSeconds
            let delay = max(0, nextAvailable - nowInterval)
            let nanos = UInt64((delay + 0.01) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
        }
    }

    private func waitForLocalPermit() async {
        var didEnterHold = false
        while true {
            let now = Date()
            pruneRequests(now: now)
            if requestTimes.count < maxRequests {
                requestTimes.append(now)
                if didEnterHold {
                    await MainActor.run {
                        InferenceActivity.shared.endGeoLookupHold()
                    }
                }
                return
            }

            if !didEnterHold {
                await MainActor.run {
                    InferenceActivity.shared.beginGeoLookupHold()
                }
                didEnterHold = true
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

    private func handleThrottleError(_ error: Error) async {
        guard throttleStore.isAvailable else { return }
        let nsError = error as NSError
        guard nsError.domain == "GEOErrorDomain", nsError.code == -3 else { return }
        guard let timeUntilReset = Self.timeUntilReset(from: nsError) else { return }
        let blockedUntil = Date().addingTimeInterval(timeUntilReset).timeIntervalSince1970
        _ = throttleStore.update { state in
            if let existing = state.blockedUntil, existing > blockedUntil {
                return
            }
            state.blockedUntil = blockedUntil
        }
    }

    private static func timeUntilReset(from error: NSError) -> TimeInterval? {
        if let value = error.userInfo["timeUntilReset"] {
            if let interval = value as? TimeInterval {
                return interval
            }
            if let number = value as? NSNumber {
                return number.doubleValue
            }
        }

        if let details = error.userInfo["details"] as? [[AnyHashable: Any]] {
            for detail in details {
                if let value = detail["timeUntilReset"] {
                    if let interval = value as? TimeInterval {
                        return interval
                    }
                    if let number = value as? NSNumber {
                        return number.doubleValue
                    }
                }
            }
        }

        return nil
    }
}

final class CLGeocoderCountryResolver: CountryResolving {

    func resolveCountry(for location: CLLocation) async -> CountryResolution? {
        await GeocodeCoordinator.shared.resolve(location: location)
    }
}
