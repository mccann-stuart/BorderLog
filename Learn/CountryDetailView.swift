//
//  CountryDetailView.swift
//  Learn
//

import SwiftUI
import SwiftData

struct CountryDetailView: View {
    let countryName: String
    let countryCode: String?
    let selectedTimeframe: VisitedCountriesTimeframe

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\PresenceDay.date, order: .reverse)]) private var allPresenceDays: [PresenceDay]
    @Query private var allCountryConfigs: [CountryConfig]

    @State private var maxAllowedDaysText: String = ""
    @State private var showAllDays: Bool = false
    @State private var ledgerRangeFilter: LedgerRangeFilter = .timeframe

    enum LedgerRangeFilter: String, CaseIterable, Identifiable {
        case timeframe = "Timeframe"
        case allTime = "All time"
        var id: String { rawValue }
    }

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

    private var filteredCountryDays: [PresenceDay] {
        switch ledgerRangeFilter {
        case .timeframe:
            let now = Date()
            let calendar = Calendar.current
            return countryDays.filter { day in
                selectedTimeframe.contains(day.date, now: now, calendar: calendar)
            }
        case .allTime:
            return countryDays
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
            Section(header: Text("Daily Ledger (\(filteredCountryDays.count) days)")) {
                Picker("Ledger Range", selection: $ledgerRangeFilter) {
                    Text(selectedTimeframe.rawValue).tag(LedgerRangeFilter.timeframe)
                    Text("All time").tag(LedgerRangeFilter.allTime)
                }
                .pickerStyle(.segmented)

                if filteredCountryDays.isEmpty {
                    ContentUnavailableView(
                        ledgerRangeFilter == .timeframe
                            ? "No days in selected period"
                            : "No Days Recorded",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text(
                            ledgerRangeFilter == .timeframe
                                ? "Switch to All time to see older days."
                                : "No presence days found for this country."
                        )
                    )
                } else {
                    let displayed = showAllDays ? filteredCountryDays : Array(filteredCountryDays.prefix(5))
                    ForEach(displayed) { day in
                        NavigationLink {
                            PresenceDayDetailView(day: day)
                        } label: {
                            PresenceDayRow(day: day)
                        }
                    }

                    if !showAllDays && filteredCountryDays.count > 5 {
                        Button {
                            withAnimation { showAllDays = true }
                        } label: {
                            Text("See All \(filteredCountryDays.count) Days")
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
        CountryDetailView(
            countryName: "France",
            countryCode: "FR",
            selectedTimeframe: .last12Months
        )
            .modelContainer(for: [PresenceDay.self, CountryConfig.self], inMemory: true)
    }
}
