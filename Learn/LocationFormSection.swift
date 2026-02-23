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

    private let countryOptions = CountryOptions.all

    private var displayCountryCode: String {
        let trimmed = countryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed.uppercased()
    }

    var body: some View {
        Section("Location") {
            if style == .picker {
                Picker("Country", selection: $countryCode) {
                    Text("Select Country").tag("")
                    ForEach(countryOptions) { option in
                        Text(option.name).tag(option.code)
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

        if let option = countryOptions.first(where: { $0.code == normalized }) {
            countryName = option.name
        } else if let localized = Locale.autoupdatingCurrent.localizedString(forRegionCode: normalized) {
            countryName = localized
        }
    }
}

private struct CountryOption: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }
}

private enum CountryOptions {
    static let all: [CountryOption] = {
        let locale = Locale.autoupdatingCurrent
        return Locale.isoRegionCodes.compactMap { code in
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
            region: .constant(.schengen)
        )
    }
}
