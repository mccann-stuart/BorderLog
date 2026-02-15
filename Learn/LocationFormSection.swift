//
//  LocationFormSection.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import SwiftUI

struct LocationFormSection: View {
    @Binding var countryName: String
    @Binding var countryCode: String
    @Binding var region: Region

    var body: some View {
        Section("Location") {
            TextField("Country", text: $countryName)

            TextField("Country Code", text: $countryCode)
                .textInputAutocapitalization(.characters)

            Picker("Region", selection: $region) {
                ForEach(Region.allCases) { region in
                    Text(region.rawValue).tag(region)
                }
            }
        }
    }
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
