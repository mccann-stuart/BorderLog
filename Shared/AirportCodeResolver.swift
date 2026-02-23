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
        let lines = csv.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.split(separator: ",")
            if parts.count >= 4 {
                let code = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                if let lat = Double(parts[1]), let lon = Double(parts[2]) {
                    let country = String(parts[3]).trimmingCharacters(in: .whitespacesAndNewlines)
                    cache[code] = AirportLocation(lat: lat, lon: lon, country: country)
                }
            }
        }
        isLoaded = true
    }
}
