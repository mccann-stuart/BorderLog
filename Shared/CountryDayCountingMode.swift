//
//  CountryDayCountingMode.swift
//  Learn
//
//  Created by Codex on 26/04/2026.
//

import Foundation

nonisolated enum CountryDayCountingMode: String, CaseIterable, Identifiable, Sendable {
    case resolvedCountry
    case doubleCountDays

    static let storageKey = "countryDayCountingMode"
    static let defaultMode: CountryDayCountingMode = .resolvedCountry

    nonisolated var id: String { rawValue }

    nonisolated var label: String {
        switch self {
        case .resolvedCountry:
            return "Resolved Country"
        case .doubleCountDays:
            return "Double Count Days"
        }
    }

    nonisolated static func storedMode(from rawValue: String?) -> CountryDayCountingMode {
        rawValue.flatMap(CountryDayCountingMode.init(rawValue:)) ?? defaultMode
    }

    nonisolated static func load(from defaults: UserDefaults = AppConfig.sharedDefaults) -> CountryDayCountingMode {
        storedMode(from: defaults.string(forKey: storageKey))
    }
}

nonisolated struct CountedPresenceCountry: Hashable, Sendable {
    let id: String
    let countryCode: String?
    let countryName: String
    let regionRaw: String

    nonisolated var isSchengen: Bool {
        guard let countryCode else { return false }
        return SchengenMembers.isMember(countryCode)
    }

    init?(countryCode: String?, countryName: String?) {
        let normalizedCode = CountryCodeNormalizer.canonicalCode(
            countryCode: countryCode,
            countryName: countryName
        )
        guard let resolvedName = CountryCodeNormalizer.canonicalName(
            countryCode: normalizedCode,
            countryName: countryName
        ) ?? normalizedCode else {
            return nil
        }

        self.id = normalizedCode ?? resolvedName
        self.countryCode = normalizedCode
        self.countryName = resolvedName
        if let normalizedCode {
            self.regionRaw = SchengenMembers.isMember(normalizedCode)
                ? Region.schengen.rawValue
                : Region.nonSchengen.rawValue
        } else {
            self.regionRaw = Region.other.rawValue
        }
    }
}

extension PresenceDay {
    func countedCountries(for mode: CountryDayCountingMode) -> [CountedPresenceCountry] {
        let allocations: ArraySlice<PresenceCountryAllocation>
        if isOverride || mode == .resolvedCountry {
            allocations = countryAllocations.prefix(1)
        } else {
            allocations = countryAllocations[...]
        }

        var countries: [CountedPresenceCountry] = []
        var seenIDs = Set<String>()

        for allocation in allocations {
            guard let country = CountedPresenceCountry(
                countryCode: allocation.countryCode,
                countryName: allocation.countryName
            ), seenIDs.insert(country.id).inserted else {
                continue
            }
            countries.append(country)
        }

        return countries
    }
}
