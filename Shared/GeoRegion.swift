//
//  GeoRegion.swift
//  Learn
//
//  Created by Mccann Stuart on 23/02/2026.
//

import Foundation

/// Geographic region grouping for ISO country codes.
/// Used by the onboarding profile setup and the country picker.
enum GeoRegion: String, CaseIterable, Identifiable {
    case northAmerica = "North America"
    case centralAmerica = "Central America"
    case caribbean = "Caribbean"
    case southAmerica = "South America"
    case europe = "Europe"
    case africa = "Africa"
    case middleEast = "Middle East"
    case asia = "Asia"
    case oceania = "Oceania"

    var id: String { rawValue }
    var displayName: String { rawValue }

    // MARK: - Lookup

    /// Returns the geographic region for a given ISO 3166-1 alpha-2 country code.
    static func region(for countryCode: String) -> GeoRegion {
        let code = countryCode.uppercased()
        return codeToRegion[code] ?? .europe // fallback; most obscure territories are European
    }

    /// All country codes belonging to this region.
    var countryCodes: [String] {
        Self.regionToCodesMap[self] ?? []
    }

    // MARK: - Data

    static let regions: [(region: GeoRegion, codes: [String])] = [
        (.northAmerica, [
            "US", "CA", "MX",
        ]),
        (.centralAmerica, [
            "GT", "HN", "SV", "NI", "CR", "BZ", "PA",
        ]),
        (.caribbean, [
            "CU", "DO", "HT", "JM", "TT", "AG", "BS", "BB", "DM", "GD", "KN", "LC", "VC",
            "AW", "AI", "BM", "VG", "KY", "CW", "GP", "MQ", "MS", "PR", "BL", "MF", "SX",
            "TC", "VI", "BQ",
        ]),
        (.southAmerica, [
            "BR", "CO", "AR", "PE", "VE", "BO", "CL", "EC", "GY", "PY", "SR", "UY",
            "GF", "FK",
        ]),
        (.europe, [
            "RU", "DE", "GB", "FR", "IT", "AL", "AD", "AT", "BY", "BE", "BA", "BG", "HR",
            "CY", "CZ", "DK", "EE", "FI", "GR", "HU", "IS", "IE", "LV", "LI", "LT", "LU",
            "MT", "MD", "MC", "ME", "NL", "MK", "NO", "PL", "PT", "RO", "SM", "RS", "SK",
            "SI", "ES", "SE", "CH", "UA", "VA", "XK",
            "GI", "FO", "GL", "GG", "IM", "JE", "AX", "SJ",
        ]),
        (.africa, [
            "NG", "ET", "EG", "CD", "TZ", "DZ", "AO", "BJ", "BW", "BF", "BI", "CV", "CM",
            "CF", "TD", "KM", "CG", "CI", "DJ", "GQ", "ER", "SZ", "GA", "GM", "GH", "GN",
            "GW", "KE", "LS", "LR", "LY", "MG", "MW", "ML", "MR", "MU", "MA", "MZ", "NA",
            "NE", "RW", "ST", "SN", "SC", "SL", "SO", "ZA", "SS", "SD", "TG", "TN", "UG",
            "ZM", "ZW", "EH", "YT", "RE",
        ]),
        (.middleEast, [
            "IR", "IQ", "SA", "YE", "SY", "BH", "IL", "JO", "KW", "LB", "OM", "PS", "QA",
            "TR", "AE",
        ]),
        (.asia, [
            "IN", "CN", "ID", "PK", "BD", "AF", "AM", "AZ", "BT", "BN", "KH", "GE", "HK",
            "JP", "KZ", "KG", "LA", "MO", "MY", "MV", "MN", "MM", "NP", "KP", "PH", "SG",
            "KR", "LK", "TW", "TJ", "TH", "TL", "TM", "UZ", "VN",
        ]),
        (.oceania, [
            "AU", "PG", "NZ", "FJ", "SB", "CK", "FM", "KI", "MH", "NR", "NU", "PW", "WS",
            "TO", "TV", "VU", "AS", "GU", "MP", "NC", "PF", "WF", "PN", "TK",
        ]),
    ]

    // MARK: - Precomputed Maps

    private static let codeToRegion: [String: GeoRegion] = {
        var map: [String: GeoRegion] = [:]
        for entry in regions {
            for code in entry.codes {
                map[code] = entry.region
            }
        }
        return map
    }()

    private static let regionToCodesMap: [GeoRegion: [String]] = {
        var map: [GeoRegion: [String]] = [:]
        for entry in regions {
            map[entry.region] = entry.codes
        }
        return map
    }()
}
