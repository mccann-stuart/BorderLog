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
    @AppStorage(CountryDayCountingMode.storageKey, store: AppConfig.sharedDefaults) private var countryDayCountingModeRaw = CountryDayCountingMode.defaultMode.rawValue

    @State private var maxAllowedDaysText: String = ""
    @State private var showAllDays: Bool = false
    @State private var ledgerRangeFilter: LedgerRangeFilter = .timeframe

    enum LedgerRangeFilter: String, CaseIterable, Identifiable {
        case timeframe = "Timeframe"
        case allTime = "All time"
        var id: String { rawValue }
    }

    private var countryDayCountingMode: CountryDayCountingMode {
        CountryDayCountingMode.storedMode(from: countryDayCountingModeRaw)
    }

    // ⚡ Bolt: Single-pass iteration to filter country and timeframe simultaneously,
    // without creating intermediate arrays (`countryDays`).
    private var filteredCountryDays: [PresenceDay] {
        let normalizedTarget = CountryCodeNormalizer.canonicalCode(
            countryCode: countryCode,
            countryName: countryName
        )
        let canonicalTargetName = CountryCodeNormalizer.canonicalName(
            countryCode: countryCode,
            countryName: countryName
        ) ?? countryName
        var results: [PresenceDay] = []

        let now = Date()
        let calendar = Calendar.current
        let isTimeframeRestricted = (ledgerRangeFilter == .timeframe)
        let dateRange = selectedTimeframe.dateRange(now: now, calendar: calendar)

        for day in allPresenceDays {
            // allPresenceDays is sorted reverse-chronologically (newest first).
            if isTimeframeRestricted, let range = dateRange, day.date < range.lowerBound {
                break // Early exit: we have evaluated everything inside our window
            }

            let matchesCountry = day.countedCountries(for: countryDayCountingMode).contains { country in
                if let target = normalizedTarget, let code = country.countryCode {
                    return target == code
                }
                return country.countryName == canonicalTargetName
            }

            if matchesCountry {
                if isTimeframeRestricted {
                    if let range = dateRange {
                        if day.date < range.upperBound {
                            results.append(day)
                        }
                    } else if selectedTimeframe.contains(day.date, now: now, calendar: calendar) {
                        results.append(day)
                    }
                } else {
                    results.append(day)
                }
            }
        }

        return results
    }

    private var countryConfig: CountryConfig? {
        let key = CountryCodeNormalizer.canonicalCode(
            countryCode: countryCode,
            countryName: countryName
        ) ?? countryName
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
        let key = CountryCodeNormalizer.canonicalCode(
            countryCode: countryCode,
            countryName: countryName
        ) ?? countryName
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
