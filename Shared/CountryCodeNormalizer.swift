//
//  CountryCodeNormalizer.swift
//  Learn
//
//  Created by Codex on 16/02/2026.
//

import Foundation

enum CountryCodeNormalizer {
    nonisolated static func normalize(_ code: String?) -> String? {
        guard let code else { return nil }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let uppercased = trimmed.uppercased()
        if uppercased == "UK" {
            return "GB"
        }
        return uppercased
    }

    nonisolated static func canonicalCode(countryCode: String?, countryName: String?) -> String? {
        if let normalizedCode = normalize(countryCode) {
            return normalizedCode
        }

        guard let normalizedName = normalizedCountryNameKey(countryName) else {
            return nil
        }
        return nameToCodeMap()[normalizedName]
    }

    nonisolated static func canonicalName(countryCode: String?, countryName: String?) -> String? {
        if let trimmedName = trimmedCountryName(countryName) {
            return trimmedName
        }

        guard let canonicalCode = canonicalCode(countryCode: countryCode, countryName: countryName) else {
            return nil
        }
        return Locale.autoupdatingCurrent.localizedString(forRegionCode: canonicalCode) ?? canonicalCode
    }

    private nonisolated static func trimmedCountryName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private nonisolated static func normalizedCountryNameKey(_ name: String?) -> String? {
        guard let trimmed = trimmedCountryName(name) else { return nil }
        let normalized = trimmed.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return normalized.lowercased()
    }

    private nonisolated static func nameToCodeMap() -> [String: String] {
        let cacheKey = "CountryCodeNormalizer.nameToCode"
        let dictionary = Thread.current.threadDictionary
        if let cached = dictionary[cacheKey] as? [String: String] {
            return cached
        }

        let mappings = buildNameToCodeMap()
        dictionary[cacheKey] = mappings
        return mappings
    }

    private nonisolated static func buildNameToCodeMap() -> [String: String] {
        let locales = [
            Locale.autoupdatingCurrent,
            Locale.current,
            Locale(identifier: "en_US"),
            Locale(identifier: "en_GB")
        ]

        var mappings: [String: String] = [
            "uk": "GB",
            "united kingdom": "GB",
            "great britain": "GB",
            "usa": "US",
            "u.s.a.": "US",
            "united states": "US",
            "united states of america": "US"
        ]

        for locale in locales {
            for region in Locale.Region.isoRegions {
                let code = region.identifier
                guard let name = locale.localizedString(forRegionCode: code),
                      let normalizedName = normalizedCountryNameKey(name) else {
                    continue
                }
                mappings[normalizedName] = mappings[normalizedName] ?? code
            }
        }

        return mappings
    }
}
