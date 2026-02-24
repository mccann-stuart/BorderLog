//
//  AirportCodeResolver.swift
//  Learn
//
//  Created by Mccann Stuart on 18/02/2026.
//

import Foundation
import CoreLocation

struct AirportLocation: Sendable {
    let lat: Double
    let lon: Double
    let country: String
}

actor AirportCodeResolver {
    static let shared = AirportCodeResolver()

    private var cache: [String: AirportLocation] = [:]
    private var isLoaded = false

    func resolve(code: String) async -> AirportLocation? {
        if !isLoaded {
            await loadData()
        }
        return cache[code.uppercased()]
    }

    private func loadData() async {
        guard !isLoaded else { return }

        // airportCodesCSV is expected to be available globally from AirportCodesData.swift
        let csv = await MainActor.run { airportCodesCSV }

        // Use enumerateLines to avoid allocating an array of all lines (O(N) memory savings)
        // Data in AirportCodesData.swift is generated clean, so trimming is unnecessary.
        csv.enumerateLines { line, _ in
            let parts = line.split(separator: ",")
            if parts.count >= 4 {
                // Parse Double directly from Substring to avoid intermediate String allocation
                if let lat = Double(parts[1]), let lon = Double(parts[2]) {
                    let code = String(parts[0])
                    let country = String(parts[3])
                    self.cache[code] = AirportLocation(lat: lat, lon: lon, country: country)
                }
            }
        }
        isLoaded = true
    }
}
