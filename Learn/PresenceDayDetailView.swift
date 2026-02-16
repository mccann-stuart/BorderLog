//
//  PresenceDayDetailView.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import SwiftUI

struct PresenceDayDetailView: View {
    let day: PresenceDay

    @State private var isShowingOverride = false

    private var dayTitle: String {
        day.dayKey
    }

    private var countryText: String {
        if let name = day.countryName ?? day.countryCode {
            return name
        }
        return "Unknown"
    }

    private var confidenceText: String {
        day.confidenceLabel.rawValue.capitalized
    }

    var body: some View {
        Form {
            Section("Summary") {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(dayTitle)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Country")
                    Spacer()
                    Text(countryText)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Confidence")
                    Spacer()
                    Text(confidenceText)
                        .foregroundStyle(.secondary)
                }

                if day.isOverride {
                    Text("This day has a manual override and will always win.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Evidence") {
                HStack {
                    Text("Stay days")
                    Spacer()
                    Text("\(day.stayCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Photos")
                    Spacer()
                    Text("\(day.photoCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Location samples")
                    Spacer()
                    Text("\(day.locationCount)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Actions") {
                Button("Override Day") {
                    isShowingOverride = true
                }
            }
        }
        .navigationTitle("Day Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingOverride) {
            NavigationStack {
                DayOverrideEditorView(
                    overrideDay: nil,
                    presetDate: day.date,
                    presetCountryName: day.countryName,
                    presetCountryCode: day.countryCode
                )
            }
        }
    }
}

#Preview {
    PresenceDayDetailView(day: PresenceDay(
        dayKey: "2026-02-15",
        date: Date(),
        timeZoneId: TimeZone.current.identifier,
        countryCode: "ES",
        countryName: "Spain",
        confidence: 0.7,
        confidenceLabel: .medium,
        sources: [.photo, .location],
        isOverride: false,
        stayCount: 1,
        photoCount: 2,
        locationCount: 3
    ))
}
