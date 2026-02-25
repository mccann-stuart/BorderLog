//
//  DailyLedgerView.swift
//  Learn
//

import SwiftUI
import SwiftData
import Foundation

enum LedgerPreFilter {
    case none
    case unknown
    case manual
    case disputed
}

struct DailyLedgerView: View {
    @Query(sort: [SortDescriptor(\PresenceDay.date, order: .reverse)]) private var allPresenceDays: [PresenceDay]
    
    var initialFilter: LedgerPreFilter = .none
    
    @State private var showUnknownOnly = false
    @State private var showLowConfidenceOnly = false
    @State private var showMediumConfidenceOnly = false
    @State private var showManualOnly = false
    @State private var showDisputedOnly = false
    @State private var didApplyInitialFilter = false

    private var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .year, value: -2, to: today) ?? today
        return (start, today)
    }

    private var recentDays: [PresenceDay] {
        let range = dateRange
        return allPresenceDays
            .filter { $0.date >= range.start && $0.date <= range.end }
            .sorted { $0.date > $1.date }
    }

    private var anyFilterActive: Bool {
        showUnknownOnly || showLowConfidenceOnly || showMediumConfidenceOnly || showManualOnly || showDisputedOnly
    }

    private var filteredDays: [PresenceDay] {
        recentDays.filter { day in
            // If no filters are active, show all
            if !anyFilterActive {
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
            if showManualOnly {
                if day.isManuallyModified {
                    matches = true
                }
            }
            if showDisputedOnly {
                if day.isDisputed && !day.isManuallyModified {
                    matches = true
                }
            }
            
            return matches
        }
    }

    var body: some View {
        List {
            Section("Days") {
                if filteredDays.isEmpty {
                    ContentUnavailableView(
                        "No matching days",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No days match the active filters in the last two years.")
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
        }
        .navigationTitle("Daily Ledger")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if anyFilterActive {
                        Button("Clear Filters") {
                            showUnknownOnly = false
                            showLowConfidenceOnly = false
                            showMediumConfidenceOnly = false
                            showManualOnly = false
                            showDisputedOnly = false
                        }
                    }
                    Toggle("Show Unknown", isOn: $showUnknownOnly)
                    Toggle("Show Disputed", isOn: $showDisputedOnly)
                    Toggle("Show Low Confidence", isOn: $showLowConfidenceOnly)
                    Toggle("Show Medium Confidence", isOn: $showMediumConfidenceOnly)
                    Toggle("Show Manually Marked", isOn: $showManualOnly)
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        // Fill the icon if any filter is active
                        .symbolVariant(anyFilterActive ? .fill : .none)
                }
            }
        }
        .onAppear {
            guard !didApplyInitialFilter else { return }
            didApplyInitialFilter = true
            switch initialFilter {
            case .none:
                break
            case .unknown:
                showUnknownOnly = true
            case .manual:
                showManualOnly = true
            case .disputed:
                showDisputedOnly = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        DailyLedgerView(initialFilter: .unknown)
            .modelContainer(for: [PresenceDay.self], inMemory: true)
    }
}
