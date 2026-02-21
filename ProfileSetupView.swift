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
            CountryRegion(name: "North America", countryCodes: ["US", "MX", "CA"]),
            CountryRegion(name: "Central America", countryCodes: ["GT", "HN", "SV", "NI", "CR", "BZ", "PA"]),
            CountryRegion(name: "Caribbean", countryCodes: ["CU", "DO", "HT", "JM", "TT", "AG", "BS", "BB", "DM", "GD", "KN", "LC", "VC"]),
            CountryRegion(name: "South America", countryCodes: ["BR", "CO", "AR", "PE", "VE", "BO", "CL", "EC", "GY", "PY", "SR", "UY"]),
            CountryRegion(
                name: "Europe",
                countryCodes: [
                    "RU", "DE", "GB", "FR", "IT", "AL", "AD", "AT", "BY", "BE", "BA", "BG", "HR",
                    "CY", "CZ", "DK", "EE", "FI", "GR", "HU", "IS", "IE", "LV", "LI", "LT", "LU",
                    "MT", "MD", "MC", "ME", "NL", "MK", "NO", "PL", "PT", "RO", "SM", "RS", "SK",
                    "SI", "ES", "SE", "CH", "UA", "VA"
                ]
            ),
            CountryRegion(
                name: "Africa",
                countryCodes: [
                    "NG", "ET", "EG", "CD", "TZ", "DZ", "AO", "BJ", "BW", "BF", "BI", "CV", "CM",
                    "CF", "TD", "KM", "CG", "CI", "DJ", "GQ", "ER", "SZ", "GA", "GM", "GH", "GN",
                    "GW", "KE", "LS", "LR", "LY", "MG", "MW", "ML", "MR", "MU", "MA", "MZ", "NA",
                    "NE", "RW", "ST", "SN", "SC", "SL", "SO", "ZA", "SS", "SD", "TG", "TN", "UG",
                    "ZM", "ZW"
                ]
            ),
            CountryRegion(
                name: "Middle East",
                countryCodes: ["IR", "IQ", "SA", "YE", "SY", "BH", "IL", "JO", "KW", "LB", "OM", "PS", "QA", "TR", "AE"]
            ),
            CountryRegion(
                name: "Asia",
                countryCodes: [
                    "IN", "CN", "ID", "PK", "BD", "AF", "AM", "AZ", "BT", "BN", "KH", "GE", "HK",
                    "JP", "KZ", "KG", "LA", "MO", "MY", "MV", "MN", "MM", "NP", "KP", "PH", "SG",
                    "KR", "LK", "TW", "TJ", "TH", "TL", "TM", "UZ", "VN"
                ]
            ),
            CountryRegion(
                name: "Oceania",
                countryCodes: [
                    "AU", "PG", "NZ", "FJ", "SB", "CK", "FM", "KI", "MH", "NR", "NU", "PW", "WS",
                    "TO", "TV", "VU"
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
