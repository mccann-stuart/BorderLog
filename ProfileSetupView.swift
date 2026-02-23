//
//  ProfileSetupView.swift
//  Learn
//

import SwiftUI

struct ProfileSetupView: View {
    @Binding var currentStep: Int
    
    @State private var passportNationality = ""
    @State private var homeCountry = ""
    
    private let keychainService = "com.MCCANN.Border"


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
    
    private func loadFromKeychain() {
        if let data = KeychainHelper.standard.read(service: keychainService, account: "userPassportNationality"),
           let value = String(data: data, encoding: .utf8) {
            passportNationality = value
        }
        if let data = KeychainHelper.standard.read(service: keychainService, account: "userHomeCountry"),
           let value = String(data: data, encoding: .utf8) {
            homeCountry = value
        }
    }

    private func saveToKeychain(key: String, value: String) {
        if value.isEmpty {
            KeychainHelper.standard.delete(service: keychainService, account: key)
        } else if let data = value.data(using: .utf8) {
            KeychainHelper.standard.save(data, service: keychainService, account: key)
        }
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
                        
                        ForEach(GeoRegion.allCases) { region in
                            Menu(region.displayName) {
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
                        
                        ForEach(GeoRegion.allCases) { region in
                            Menu(region.displayName) {
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
        .onAppear {
            loadFromKeychain()
        }
        .onChange(of: passportNationality) { _, newValue in
            saveToKeychain(key: "userPassportNationality", value: newValue)
        }
        .onChange(of: homeCountry) { _, newValue in
            saveToKeychain(key: "userHomeCountry", value: newValue)
        }
    }
}

#Preview {
    ProfileSetupView(currentStep: .constant(1))
}
