//
//  DailyLedgerView.swift
//  Learn
//

import SwiftUI
import SwiftData

struct DailyLedgerView: View {
    @Query(sort: [SortDescriptor(\PresenceDay.date, order: .reverse)]) private var allPresenceDays: [PresenceDay]
    
    @State private var showUnknownOnly = false
    @State private var showLowConfidenceOnly = false
    @State private var showMediumConfidenceOnly = false

    private var filteredDays: [PresenceDay] {
        allPresenceDays.filter { day in
            // If no filters are active, show all
            if !showUnknownOnly && !showLowConfidenceOnly && !showMediumConfidenceOnly {
                return true
            }
            
            // If multiple filters are active, we show days matching ANY of the active filters (OR logic)
            var matches = false
            
            if showUnknownOnly {
                if day.countryCode == nil && day.countryName == nil {
                    matches = true
                }
            }
            if showLowConfidenceOnly {
                if day.confidenceLabel == .low {
                    matches = true
                }
            }
            if showMediumConfidenceOnly {
                if day.confidenceLabel == .medium {
                    matches = true
                }
            }
            
            return matches
        }
    }

    var body: some View {
        List {
            if filteredDays.isEmpty {
                ContentUnavailableView(
                    "No matching days",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("No days match the active filters.")
                )
            } else {
                ForEach(filteredDays) { day in
                    NavigationLink {
                        PresenceDayDetailView(day: day)
                    } label: {
                        PresenceDayRow(day: day)
                    }
                }
            }
        }
        .navigationTitle("Daily Ledger")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle("Show Unknown", isOn: $showUnknownOnly)
                    Toggle("Show Low Confidence", isOn: $showLowConfidenceOnly)
                    Toggle("Show Medium Confidence", isOn: $showMediumConfidenceOnly)
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        // Fill the icon if any filter is active
                        .symbolVariant((showUnknownOnly || showLowConfidenceOnly || showMediumConfidenceOnly) ? .fill : .none)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DailyLedgerView()
            .modelContainer(for: [PresenceDay.self], inMemory: true)
    }
}
