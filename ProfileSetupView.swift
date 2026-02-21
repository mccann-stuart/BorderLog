//
//  ProfileSetupView.swift
//  Learn
//

import SwiftUI

struct ProfileSetupView: View {
    @Binding var currentStep: Int
    
    @AppStorage("userPassportNationality") private var passportNationality = ""
    @AppStorage("userHomeCountry") private var homeCountry = ""
    
    private struct CountryRegion: Identifiable {
        let id = UUID()
        let name: String
        let countryCodes: [String]
    }
    
    private var countryRegions: [CountryRegion] {
        [
            CountryRegion(name: "North America", countryCodes: ["CA", "MX", "US"]),
            CountryRegion(name: "Central America", countryCodes: ["BZ", "CR", "SV", "GT", "HN", "NI", "PA"]),
            CountryRegion(name: "Caribbean", countryCodes: ["AG", "BS", "BB", "CU", "DM", "DO", "GD", "HT", "JM", "KN", "LC", "VC", "TT"]),
            CountryRegion(name: "South America", countryCodes: ["AR", "BO", "BR", "CL", "CO", "EC", "GY", "PY", "PE", "SR", "UY", "VE"]),
            CountryRegion(
                name: "Europe",
                countryCodes: [
                    "AD", "AL", "AT", "BA", "BE", "BG", "BY", "CH", "CY", "CZ", "DE", "DK", "EE",
                    "ES", "FI", "FR", "GB", "GR", "HR", "HU", "IE", "IS", "IT", "LI", "LT", "LU",
                    "LV", "MC", "MD", "ME", "MK", "MT", "NL", "NO", "PL", "PT", "RO", "RS", "RU",
                    "SE", "SI", "SK", "SM", "UA", "VA"
                ]
            ),
            CountryRegion(
                name: "Africa",
                countryCodes: [
                    "DZ", "AO", "BJ", "BW", "BF", "BI", "CM", "CV", "CF", "TD", "KM", "CG", "CD",
                    "CI", "DJ", "EG", "GQ", "ER", "SZ", "ET", "GA", "GM", "GH", "GN", "GW", "KE",
                    "LS", "LR", "LY", "MG", "MW", "ML", "MR", "MU", "MA", "MZ", "NA", "NE", "NG",
                    "RW", "ST", "SN", "SC", "SL", "SO", "ZA", "SS", "SD", "TZ", "TG", "TN", "UG",
                    "ZM", "ZW"
                ]
            ),
            CountryRegion(
                name: "Middle East",
                countryCodes: ["AE", "BH", "IL", "IQ", "IR", "JO", "KW", "LB", "OM", "PS", "QA", "SA", "SY", "TR", "YE"]
            ),
            CountryRegion(
                name: "Asia",
                countryCodes: [
                    "AF", "AM", "AZ", "BD", "BN", "BT", "CN", "GE", "HK", "ID", "IN", "JP", "KG",
                    "KH", "KP", "KR", "KZ", "LA", "LK", "MM", "MN", "MO", "MV", "MY", "NP", "PH",
                    "PK", "SG", "TH", "TJ", "TM", "TW", "UZ", "VN", "TL"
                ]
            ),
            CountryRegion(
                name: "Oceania",
                countryCodes: [
                    "AU", "NZ", "FJ", "PG", "SB", "VU", "WS", "TO", "TV", "KI", "NR", "PW", "FM",
                    "MH", "CK", "NU"
                ]
            )
        ]
    }
    
    private func countryDisplayName(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }
    
    private func countryLabel(for code: String) -> String {
        "\(countryDisplayName(for: code)) (\(code))"
    }
    
    private func selectedCountryLabel(for code: String) -> String {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Not set"
        }
        return countryLabel(for: code)
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Header Image
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            // Text
            VStack(spacing: 8) {
                Text("Your Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("This information is optional and stays on your device. It helps BorderLog personalize your tracking")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Form Elements
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Passport Nationality")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Menu {
                        Button("Clear Selection") {
                            passportNationality = ""
                        }
                        
                        ForEach(countryRegions) { region in
                            Menu(region.name) {
                                ForEach(region.countryCodes, id: \.self) { code in
                                    Button(countryLabel(for: code)) {
                                        passportNationality = code
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedCountryLabel(for: passportNationality))
                                .foregroundStyle(passportNationality.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Home Country")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Menu {
                        Button("Clear Selection") {
                            homeCountry = ""
                        }
                        
                        ForEach(countryRegions) { region in
                            Menu(region.name) {
                                ForEach(region.countryCodes, id: \.self) { code in
                                    Button(countryLabel(for: code)) {
                                        homeCountry = code
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedCountryLabel(for: homeCountry))
                                .foregroundStyle(homeCountry.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Navigation
            VStack(spacing: 16) {
                Button {
                    withAnimation {
                        currentStep = 2
                    }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                Button {
                    // Skip just moves to the next step without requiring input
                    withAnimation {
                        currentStep = 2
                    }
                } label: {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    ProfileSetupView(currentStep: .constant(1))
}
