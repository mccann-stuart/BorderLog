//
//  CountryDetailView.swift
//  Learn
//

import SwiftUI
import SwiftData

struct CountryDetailView: View {
    let countryName: String
    let countryCode: String?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\PresenceDay.date, order: .forward)]) private var allPresenceDays: [PresenceDay]
    @Query private var allCountryConfigs: [CountryConfig]

    @State private var maxAllowedDaysText: String = ""
    @State private var showAllDays: Bool = false

    // Days filtered to this country only
    private var countryDays: [PresenceDay] {
        let normalizedTarget = CountryCodeNormalizer.normalize(countryCode)
        return allPresenceDays.filter { day in
            let normalizedDay = CountryCodeNormalizer.normalize(day.countryCode)
            if let target = normalizedTarget, let code = normalizedDay {
                return target == code
            }
            return (day.countryName ?? "") == countryName
        }
    }

    private var countryConfig: CountryConfig? {
        let key = CountryCodeNormalizer.normalize(countryCode) ?? countryName
        return allCountryConfigs.first { $0.countryCode == key }
    }

    var body: some View {
        List {
            // ── Configuration ──────────────────────────────────────
            Section(header: Text("Configuration")) {
                HStack {
                    Text("Max Allowed Days")
                    Spacer()
                    TextField("Unlimited", text: $maxAllowedDaysText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: maxAllowedDaysText) { _, newValue in
                            saveConfig(newValue: newValue)
                        }
                }
            }

            // ── Daily Ledger ───────────────────────────────────────
            Section(header: Text("Daily Ledger (\(countryDays.count) days)")) {
                if countryDays.isEmpty {
                    ContentUnavailableView(
                        "No Days Recorded",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No presence days found for this country.")
                    )
                } else {
                    let displayed = showAllDays ? countryDays : Array(countryDays.prefix(5))
                    ForEach(displayed) { day in
                        NavigationLink {
                            PresenceDayDetailView(day: day)
                        } label: {
                            PresenceDayRow(day: day)
                        }
                    }

                    if !showAllDays && countryDays.count > 5 {
                        Button {
                            withAnimation { showAllDays = true }
                        } label: {
                            Text("See All \(countryDays.count) Days")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .navigationTitle(countryName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let maxDays = countryConfig?.maxAllowedDays {
                maxAllowedDaysText = String(maxDays)
            }
        }
    }

    private func saveConfig(newValue: String) {
        let key = CountryCodeNormalizer.normalize(countryCode) ?? countryName
        let parsedDays = Int(newValue)

        if let existing = countryConfig {
            existing.maxAllowedDays = parsedDays
        } else {
            let newConfig = CountryConfig(countryCode: key, maxAllowedDays: parsedDays)
            modelContext.insert(newConfig)
        }
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        CountryDetailView(countryName: "France", countryCode: "FR")
            .modelContainer(for: [PresenceDay.self, CountryConfig.self], inMemory: true)
    }
}
