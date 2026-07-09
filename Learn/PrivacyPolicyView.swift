//
//  PrivacyPolicyView.swift
//  Learn
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("Summary") {
                Text("BorderLog is local-first. Travel data is stored on this device. BorderLog does not run advertising, analytics, third-party tracking, or app-owned user-data servers.")
            }

            Section("Data Sources") {
                PrivacyPolicyRow(
                    title: "Location",
                    detail: "Optional location access is used to infer daily country presence and to let the widget record opportunistic location samples. Apple system services such as MapKit geocoding may process coordinates to resolve country names."
                )
                PrivacyPolicyRow(
                    title: "Photos",
                    detail: "Optional Photos access is used to read photo location metadata. BorderLog does not upload photos."
                )
                PrivacyPolicyRow(
                    title: "Calendar",
                    detail: "Optional Calendar access is read-only and is used to infer travel days from events such as flights. BorderLog never writes to the user's calendar."
                )
                PrivacyPolicyRow(
                    title: "Profile",
                    detail: "Passport nationality, home country, and local session identifiers are stored on device to personalize calculations and app state."
                )
            }

            Section("Controls") {
                Text("Data remains on this device until you delete it or use Reset All Data. Permissions can be changed in iOS Settings. Reset All Data deletes local travel records, Keychain-backed profile and session values, and pending widget samples. Use Reset All Data before uninstalling BorderLog to ensure those Keychain values are removed.")
            }

            Section("Tracking") {
                Text("BorderLog does not track users across apps or websites owned by other companies.")
            }

            Section("Support") {
                Text("Support and privacy contact details are available through the Support URL on BorderLog's App Store page. Do not include private travel data in a public support request.")
            }
        }
        .navigationTitle("Privacy Policy")
    }
}

private struct PrivacyPolicyRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
