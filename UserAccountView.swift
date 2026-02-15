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
                
                Section("Data Sync") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("iCloud Sync")
                                .font(.headline)
                            Spacer()
                            Text("Not Configured")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Enable iCloud to sync your travel data across devices. Configure in a future milestone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Button("Sign Out", role: .destructive) {
                        isConfirmingSignOut = true
                    }
                }
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
