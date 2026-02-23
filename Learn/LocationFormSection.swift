//
//  LocationFormSection.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import SwiftUI

enum LocationFormStyle {
    case freeText
    case picker
}

struct LocationFormSection: View {
    @Binding var countryName: String
    @Binding var countryCode: String
    @Binding var region: Region
    var style: LocationFormStyle = .freeText

    /// Up to 3 country codes to feature as top suggestions (derived from PresenceDay).
    var suggestedCodes: [String] = []
    /// Countries already in the daily ledger with their day counts, sorted descending.
    var ledgerCountryCounts: [(code: String, count: Int)] = []

    private let allCountryOptions = CountryOptions.all

    private var displayCountryCode: String {
        let trimmed = countryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed.uppercased()
    }

    // MARK: - Computed Sections

    private var suggestionOptions: [CountryOption] {
        suggestedCodes.compactMap { code in
            allCountryOptions.first(where: { $0.code == code.uppercased() })
        }
    }

    private var ledgerOptions: [CountryOption] {
        let suggestedSet = Set(suggestedCodes.map { $0.uppercased() })
        return ledgerCountryCounts.compactMap { item in
            let code = item.code.uppercased()
            guard !suggestedSet.contains(code) else { return nil }
            return allCountryOptions.first(where: { $0.code == code })
        }
    }

    private var regionGroupedOptions: [(region: GeoRegion, countries: [CountryOption])] {
        let usedCodes = Set(
            suggestedCodes.map { $0.uppercased() } +
            ledgerCountryCounts.map { $0.code.uppercased() }
        )

        let remaining = allCountryOptions.filter { !usedCodes.contains($0.code) }

        var grouped: [GeoRegion: [CountryOption]] = [:]
        for option in remaining {
            let geo = GeoRegion.region(for: option.code)
            grouped[geo, default: []].append(option)
        }

        return GeoRegion.allCases.compactMap { geo in
            guard let countries = grouped[geo], !countries.isEmpty else { return nil }
            return (region: geo, countries: countries)
        }
    }

    private var hasTieredData: Bool {
        !suggestedCodes.isEmpty || !ledgerCountryCounts.isEmpty
    }

    // MARK: - Body

    var body: some View {
        Section("Location") {
            if style == .picker {
                Group {
                    if hasTieredData {
                        tieredPicker
                    } else {
                        flatPicker
                    }
                }
                .onAppear { syncCountryName(for: countryCode) }
                .onChange(of: countryCode) { _, newValue in
                    syncCountryName(for: newValue)
                }

                LabeledContent("Country Code") {
                    Text(displayCountryCode)
                        .foregroundStyle(.secondary)
                }
            } else {
                TextField("Country", text: $countryName)

                TextField("Country Code", text: $countryCode)
                    .textInputAutocapitalization(.characters)
            }

            Picker("Region", selection: $region) {
                ForEach(Region.allCases) { region in
                    Text(region.rawValue).tag(region)
                }
            }
        }
    }

    // MARK: - Pickers

    private var flatPicker: some View {
        Picker("Country", selection: $countryCode) {
            Text("Select Country").tag("")
            ForEach(allCountryOptions) { option in
                Text(option.name).tag(option.code)
            }
        }
    }

    private var tieredPicker: some View {
        Picker("Country", selection: $countryCode) {
            Text("Select Country").tag("")

            let suggestions = suggestionOptions
            if !suggestions.isEmpty {
                Section("Suggestions") {
                    ForEach(suggestions) { option in
                        Text(option.name).tag(option.code)
                    }
                }
            }

            let ledger = ledgerOptions
            if !ledger.isEmpty {
                Section("Recent Countries") {
                    ForEach(ledger) { option in
                        Text(option.name).tag(option.code)
                    }
                }
            }

            ForEach(regionGroupedOptions, id: \.region) { group in
                Section(group.region.displayName) {
                    ForEach(group.countries) { option in
                        Text(option.name).tag(option.code)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func syncCountryName(for code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            countryName = ""
            return
        }

        let normalized = trimmed.uppercased()
        if normalized != code {
            countryCode = normalized
        }

        if let option = allCountryOptions.first(where: { $0.code == normalized }) {
            countryName = option.name
        } else if let localized = Locale.autoupdatingCurrent.localizedString(forRegionCode: normalized) {
            countryName = localized
        }
    }
}

struct CountryOption: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }
}

enum CountryOptions {
    static let all: [CountryOption] = {
        let locale = Locale.autoupdatingCurrent
        return Locale.Region.isoRegions.compactMap { region in
            let code = region.identifier
            guard let name = locale.localizedString(forRegionCode: code) else { return nil }
            return CountryOption(code: code, name: name)
        }
        .sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }()
}

#Preview {
    Form {
        LocationFormSection(
            countryName: .constant("France"),
            countryCode: .constant("FR"),
            region: .constant(.schengen),
            style: .picker,
            suggestedCodes: ["ES", "FR", "PT"],
            ledgerCountryCounts: [("DE", 45), ("IT", 30), ("NL", 12)]
        )
    }
}
