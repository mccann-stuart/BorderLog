//
//  CountryResolver.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation
import CoreLocation
import MapKit
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

final class CLGeocoderCountryResolver: CountryResolving {
    private let cache = CountryResolutionCache()

    func resolveCountry(for location: CLLocation) async -> CountryResolution? {
        let key = cacheKey(for: location)
        if let cached = await cache.value(for: key) {
            return cached
        }

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
