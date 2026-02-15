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

    var body: some View {
        if authManager.appleUserId.isEmpty {
            SignInView()
                .environmentObject(authManager)
        } else {
            ContentView()
                .environmentObject(authManager)
        }
    }
}

private struct SignInView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var isShowingError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 18) {
            Text("BorderLog")
                .font(.largeTitle.bold())

            Text("Sign in with Apple is required to use BorderLog. Your travel data stays on this device unless you enable iCloud sync.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                        authManager.signIn(userId: credential.user)
                    } else {
                        showError("Unable to read Apple ID credential.")
                    }
                case .failure(let error):
                    showError(error.localizedDescription)
                }
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
}

#Preview {
    RootView()
}
