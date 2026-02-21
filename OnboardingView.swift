//
//  OnboardingView.swift
//  Learn
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var currentStep = 0
    
    var body: some View {
        NavigationStack {
            TabView(selection: $currentStep) {
                WelcomeView(currentStep: $currentStep)
                    .tag(0)
                
                ProfileSetupView(currentStep: $currentStep)
                    .tag(1)
                
                PermissionsRequestView {
                    completeOnboarding()
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // Hide the default dots
            .ignoresSafeArea(.keyboard)
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthenticationManager())
}
