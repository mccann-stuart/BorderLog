//
//  CountryResolver.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import CoreLocation

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

final class CLGeocoderCountryResolver: CountryResolving {
    private let geocoder = CLGeocoder()
    private let cache = CountryResolutionCache()

    func resolveCountry(for location: CLLocation) async -> CountryResolution? {
        let key = cacheKey(for: location)
        if let cached = await cache.value(for: key) {
            return cached
        }

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let placemark = placemarks.first
            let resolution = CountryResolution(
                countryCode: placemark?.isoCountryCode,
                countryName: placemark?.country,
                timeZone: placemark?.timeZone
            )
            if resolution.countryCode != nil || resolution.countryName != nil {
                await cache.set(resolution, for: key)
            }
            return resolution
        } catch {
            return nil
        }
    }

    private func cacheKey(for location: CLLocation) -> String {
        let lat = String(format: "%.3f", location.coordinate.latitude)
        let lon = String(format: "%.3f", location.coordinate.longitude)
        return "\(lat),\(lon)"
    }
}
