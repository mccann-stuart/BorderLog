//
//  GeoRegion.swift
//  Learn
//
//  Created by Mccann Stuart on 23/02/2026.
//

import Foundation

enum GeoRegion: String, CaseIterable, Identifiable {
    case europe = "Europe"
    case americas = "Americas"
    case asiaPacific = "Asia & Pacific"
    case middleEastAfrica = "Middle East & Africa"
    case other = "Other"

    var id: String { rawValue }

    var displayName: String { rawValue }

    // MARK: - Country Code → Region Mapping

    static func region(for countryCode: String) -> GeoRegion {
        let code = countryCode.uppercased()
        if europeCodes.contains(code) { return .europe }
        if americasCodes.contains(code) { return .americas }
        if asiaPacificCodes.contains(code) { return .asiaPacific }
        if middleEastAfricaCodes.contains(code) { return .middleEastAfrica }
        return .other
    }

    // MARK: - Region Sets

    private static let europeCodes: Set<String> = [
        // EU / Schengen / EEA
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR",
        "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL",
        "PL", "PT", "RO", "SK", "SI", "ES", "SE",
        // EFTA / Other Europe
        "IS", "LI", "NO", "CH",
        "GB", "AL", "AD", "AM", "AZ", "BY", "BA", "GE", "GI", "XK",
        "MD", "MC", "ME", "MK", "RS", "SM", "TR", "UA", "VA",
        // Territories
        "FO", "GL", "GG", "IM", "JE", "AX", "SJ",
    ]

    private static let americasCodes: Set<String> = [
        // North America
        "US", "CA", "MX",
        // Central America
        "BZ", "CR", "SV", "GT", "HN", "NI", "PA",
        // Caribbean
        "AG", "BS", "BB", "CU", "DM", "DO", "GD", "HT", "JM", "KN",
        "LC", "VC", "TT",
        "AW", "AI", "BM", "VG", "KY", "CW", "GP", "MQ", "MS", "PR",
        "BL", "MF", "SX", "TC", "VI", "BQ",
        // South America
        "AR", "BO", "BR", "CL", "CO", "EC", "FK", "GF", "GY", "PY",
        "PE", "SR", "UY", "VE",
    ]

    private static let asiaPacificCodes: Set<String> = [
        // East Asia
        "CN", "JP", "KR", "KP", "MN", "TW", "HK", "MO",
        // Southeast Asia
        "BN", "KH", "ID", "LA", "MY", "MM", "PH", "SG", "TH", "TL", "VN",
        // South Asia
        "AF", "BD", "BT", "IN", "MV", "NP", "LK", "PK",
        // Central Asia
        "KZ", "KG", "TJ", "TM", "UZ",
        // Oceania
        "AU", "NZ", "FJ", "PG", "SB", "VU", "WS", "TO", "KI", "MH",
        "FM", "NR", "PW", "TV", "CK", "NU", "TK", "AS", "GU", "MP",
        "NC", "PF", "WF", "PN",
    ]

    private static let middleEastAfricaCodes: Set<String> = [
        // Middle East
        "BH", "IR", "IQ", "IL", "JO", "KW", "LB", "OM", "PS", "QA",
        "SA", "SY", "AE", "YE",
        // North Africa
        "DZ", "EG", "LY", "MA", "TN", "EH", "MR",
        // Sub-Saharan Africa
        "AO", "BJ", "BW", "BF", "BI", "CV", "CM", "CF", "TD", "KM",
        "CG", "CD", "CI", "DJ", "GQ", "ER", "SZ", "ET", "GA", "GM",
        "GH", "GN", "GW", "KE", "LS", "LR", "MG", "MW", "ML", "MU",
        "YT", "MZ", "NA", "NE", "NG", "RE", "RW", "ST", "SN", "SC",
        "SL", "SO", "ZA", "SS", "SD", "TZ", "TG", "UG", "ZM", "ZW",
    ]
}
