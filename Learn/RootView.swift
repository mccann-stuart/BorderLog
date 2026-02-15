//
//  RootView.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import SwiftUI
import AuthenticationServices

struct RootView: View {
    @StateObject private var authManager = AuthenticationManager()
    @AppStorage("hasCompletedFirstLaunch") private var hasCompletedFirstLaunch = false

    var body: some View {
        Group {
            if AuthenticationManager.isAppleSignInEnabled {
                if authManager.appleUserId.isEmpty {
                    if hasCompletedFirstLaunch {
                        SignInScreen(
                            title: "Sign in to Border Log",
                            subtitle: "Sign up with Apple ID to access your travel history on this device",
                            showHighlights: false,
                            onSignedIn: {}
                        )
                    } else {
                        SignInScreen(
                            title: "Welcome to Border Log",
                            subtitle: "Track country stays, stay compliant, and keep your data on-device",
                            showHighlights: true,
                            onSignedIn: {
                                hasCompletedFirstLaunch = true
                            }
                        )
                    }
                } else {
                    MainNavigationView()
                }
            } else {
                MainNavigationView()
            }
        }
        .environmentObject(authManager)
        .onAppear {
            guard AuthenticationManager.isAppleSignInEnabled else { return }
            if !authManager.appleUserId.isEmpty && !hasCompletedFirstLaunch {
                hasCompletedFirstLaunch = true
            }
        }
    }
}

private struct SignInScreen: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var isShowingError = false
    @State private var errorMessage = ""
    
    let title: String
    let subtitle: String
    let showHighlights: Bool
    let onSignedIn: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                Text(title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if showHighlights {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Log stays with dates and notes", systemImage: "calendar")
                    Label("See visa usage", systemImage: "gauge.with.dots.needle.67percent")
                    Label("Keep data local, always", systemImage: "lock.fill")
                }
                .font(.callout)
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, 4)
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = []
            } onCompletion: { result in
                handleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: 520)
        .padding(32)
        .alert("Sign in failed", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }
    
    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                authManager.signIn(userId: credential.user)
                onSignedIn()
            } else {
                showError("Unable to read Apple ID credential.")
            }
        case .failure(let error):
            showError(error.localizedDescription)
        }
    }
}

#Preview {
    RootView()
}
