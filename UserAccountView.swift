//
//  UserAccountView.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import SwiftUI

struct UserAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var isConfirmingSignOut = false
    
    var body: some View {
        NavigationStack {
            Form {
                accountSection
                dataSyncSection
                signOutSection
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Sign out of BorderLog?", isPresented: $isConfirmingSignOut) {
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                    dismiss()
                }
            } message: {
                Text("Your data will remain on this device. Sign in again to access your account.")
            }
        }
    }
    
    @ViewBuilder
    private var accountSection: some View {
        if AuthenticationManager.isAppleSignInEnabled {
            Section("Account") {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Signed in with Apple")
                            .font(.headline)

                        Text(maskedUserId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Authentication") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sign in with Apple")
                        .font(.headline)
                    Text("Your Apple ID is used for authentication. BorderLog does not have access to your email or personal information.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Section("Account") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Use without an account")
                        .font(.headline)
                    Text("BorderLog does not require an account. Your travel data stays on this device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private var dataSyncSection: some View {
        Section("Data Sync") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("iCloud Sync")
                        .font(.headline)
                    Spacer()
                    Text("Off")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("BorderLog currently stores travel data locally on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var signOutSection: some View {
        if AuthenticationManager.isAppleSignInEnabled {
            Section {
                Button("Sign Out", role: .destructive) {
                    isConfirmingSignOut = true
                }
            }
        }
    }

    private var maskedUserId: String {
        let userId = authManager.appleUserId
        guard userId.count > 8 else { return userId }
        let prefix = String(userId.prefix(4))
        let suffix = String(userId.suffix(4))
        return "\(prefix)...\(suffix)"
    }
}

#Preview {
    UserAccountView()
        .environmentObject(AuthenticationManager())
}
