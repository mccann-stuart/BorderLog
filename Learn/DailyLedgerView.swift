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
        // Since allPresenceDays is fetched with a SortDescriptor ordering by date reverse,
        // we can safely use filter, but .sorted is redundant. To avoid intermediate arrays, use lazy where possible,
        // but since we need an Array for the view and further filtering, we just use a single pass filter.
        return allPresenceDays.filter { $0.date >= range.start && $0.date <= range.end }
    }

    private var disputedDayCount: Int {
        // Optimization: Use `lazy` to avoid allocating an intermediate array just to count.
        recentDays.lazy.filter { $0.isDisputed && !$0.isManuallyModified }.count
    }

    private var anyFilterActive: Bool {
        showUnknownOnly || showLowConfidenceOnly || showMediumConfidenceOnly || showManualOnly || showDisputedOnly
    }

    private var filteredDays: [PresenceDay] {
        if !anyFilterActive {
            return recentDays // O(1) return via copy-on-write
        }

        // Single pass standard filter is generally faster than Array(.lazy.filter) due to buffer capacities.
        return recentDays.filter { day in
            // If multiple filters are active, we show days matching ANY of the active filters (OR logic)
            if showUnknownOnly && day.countryCode == nil && day.countryName == nil { return true }
            if showLowConfidenceOnly && day.confidenceLabel == .low { return true }
            if showMediumConfidenceOnly && day.confidenceLabel == .medium { return true }
            if showManualOnly && day.isManuallyModified { return true }
            if showDisputedOnly && day.isDisputed && !day.isManuallyModified { return true }
            
            return false
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
                    Toggle("Show Disputed (\(disputedDayCount))", isOn: $showDisputedOnly)
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
