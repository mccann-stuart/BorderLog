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
    @Query(sort: [SortDescriptor(\PresenceDay.date, order: .reverse)]) private var allPresenceDays: [PresenceDay]
    @Query private var countryConfigs: [CountryConfig]
    
    @State private var maxAllowedDaysText: String = ""
    @State private var showAllDays: Bool = false
    
    // Filter days for this country
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
        let normalizedTarget = CountryCodeNormalizer.normalize(countryCode)
        return countryConfigs.first { config in
            config.countryCode == (normalizedTarget ?? countryName)
        }
    }
    
    var body: some View {
        List {
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
            
            Section(header: Text("Daily Ledger (\(countryDays.count) Days)")) {
                if countryDays.isEmpty {
                    ContentUnavailableView(
                        "No Days Recorded",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No presence days found for this country.")
                    )
                } else {
                    let displayDays = showAllDays ? countryDays : Array(countryDays.prefix(5))
                    ForEach(displayDays) { day in
                        NavigationLink {
                            PresenceDayDetailView(day: day)
                        } label: {
                            PresenceDayRow(day: day)
                        }
                    }
                    
                    if !showAllDays && countryDays.count > 5 {
                        Button {
                            withAnimation {
                                showAllDays = true
                            }
                        } label: {
                            Text("See All")
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle(countryName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let config = countryConfig, let maxDays = config.maxAllowedDays {
                maxAllowedDaysText = String(maxDays)
            }
        }
    }
    
    private func saveConfig(newValue: String) {
        let normalizedTarget = CountryCodeNormalizer.normalize(countryCode) ?? countryName
        let newMaxDays = Int(newValue)
        
        if let existingConfig = countryConfig {
            existingConfig.maxAllowedDays = newMaxDays
        } else {
            let newConfig = CountryConfig(countryCode: normalizedTarget, maxAllowedDays: newMaxDays)
            modelContext.insert(newConfig)
        }
        try? modelContext.save()
    }
}
