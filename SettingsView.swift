//
//  SettingsView.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isConfirmingReset = false
    @State private var isShowingSeedAlert = false
    
    private var dataManager: DataManager {
        DataManager(modelContext: modelContext)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Data Management") {
                    Button("Seed Sample Data") {
                        seedSampleData()
                    }
                    
                    Button("Reset All Data", role: .destructive) {
                        isConfirmingReset = true
                    }
                }
                
                Section("About") {
                    NavigationLink("About / Setup") {
                        AboutSetupView()
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Configuration") {
                    HStack {
                        Text("Schengen Membership")
                        Spacer()
                        Text("Hard-coded (M1)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Privacy") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Local-First Storage")
                            .font(.headline)
                        Text("All your travel data is stored locally on this device. No data is sent to external servers unless you enable iCloud sync.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Delete all local data?", isPresented: $isConfirmingReset) {
                Button("Delete All", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will remove all stays and day overrides from this device.")
            }
            .alert("Sample data unavailable", isPresented: $isShowingSeedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Reset all data before seeding the sample dataset.")
            }
        }
    }
    
    private func resetAllData() {
        do {
            try dataManager.resetAllData()
        } catch {
            print("Failed to reset data: \(error)")
        }
    }
    
    private func seedSampleData() {
        do {
            if try !dataManager.seedSampleData() {
                isShowingSeedAlert = true
            }
        } catch {
            print("Failed to seed data: \(error)")
        }
    }
}

struct AboutSetupView: View {
    var body: some View {
        Form {
            Section("About") {
                Text("BorderLog is a privacy-first, local-first app for tracking days in/out and Schengen 90/180.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Setup") {
                Text("App Group: configure Info.plist key 'AppGroupId' and enable the App Groups capability.")
                Text("Sign in with Apple: required. Enable capability and use the system button.")
                Text("iCloud: optional for M1. Add later if you want device sync.")
            }

            Section("Data Sources (M1)") {
                Text("Manual stays and day overrides only. Inference via widgets and photos arrives in M2.")
            }
        }
        .navigationTitle("About / Setup")
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Stay.self, DayOverride.self], inMemory: true)
}
