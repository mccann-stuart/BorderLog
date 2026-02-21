//
//  WelcomeView.swift
//  Learn
//

import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @Binding var currentStep: Int
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Header Image
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            // Welcome Text
            VStack(spacing: 16) {
                Text("Welcome to BorderLog")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Track your days in and out of countries with privacy-first on-device inference. Built for expats and frequent travelers.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Value Props
            VStack(alignment: .leading, spacing: 24) {
                ValuePropRow(
                    icon: "lock.fill",
                    color: .green,
                    title: "Local-First Privacy",
                    description: "Your travel data stays on this device. No cloud analytics, no server storage."
                )
                
                ValuePropRow(
                    icon: "calendar.badge.clock",
                    color: .blue,
                    title: "Schengen 90/180",
                    description: "Effortlessly monitor your Schengen limit and avoid overstays."
                )
                
                ValuePropRow(
                    icon: "wand.and.stars",
                    color: .purple,
                    title: "Smart Inference",
                    description: "BorderLog infers your location using on-device signals, minimizing manual entry."
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            Spacer()
            
            // Authentication
            VStack(spacing: 16) {
                if AuthenticationManager.isAppleSignInEnabled {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [] // We only need the user ID
                    } onCompletion: { result in
                        handleAppleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(8)
                    .padding(.horizontal, 32)
                } else {
                    Button {
                        // In local-only mode, any ID will do to bypass auth
                        authManager.signIn(userId: "local_user_\(UUID().uuidString)")
                        withAnimation {
                            currentStep = 1
                        }
                    } label: {
                        Text("Continue (Local Mode)")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    
                    Text("Sign in with Apple is currently disabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userId = appleIDCredential.user
                authManager.signIn(userId: userId)
                
                // Move to next step on success
                withAnimation {
                    currentStep = 1
                }
            }
        case .failure(let error):
            print("Apple Sign In failed: \(error.localizedDescription)")
            // In a real app, you might show an error alert here. For now we stay on this screen.
        }
    }
}

private struct ValuePropRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    WelcomeView(currentStep: .constant(0))
        .environmentObject(AuthenticationManager())
}
