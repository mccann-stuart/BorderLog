//
//  ProfileSetupView.swift
//  Learn
//

import SwiftUI

struct ProfileSetupView: View {
    @Binding var currentStep: Int
    
    @AppStorage("userPassportNationality") private var passportNationality = ""
    @AppStorage("userHomeCountry") private var homeCountry = ""
    
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
                
                Text("This information is optional and stays on your device. It helps BorderLog personalize your tracking.")
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
                    
                    TextField("e.g., USA, GBR, FRA", text: $passportNationality)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Home Country")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    TextField("e.g., ESP, DEU, ITA", text: $homeCountry)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
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
