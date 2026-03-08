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

    private var anyFilterActive: Bool {
        showUnknownOnly || showLowConfidenceOnly || showMediumConfidenceOnly || showManualOnly || showDisputedOnly
    }

    // ⚡ Bolt: Single-pass iteration to filter days and count disputed days in O(N) time and O(1) space overhead
    private var filteredData: (days: [PresenceDay], disputedCount: Int) {
        let range = dateRange
        var matchingDays: [PresenceDay] = []
        var disputedCount = 0
        let isAnyFilterActive = anyFilterActive

        for day in allPresenceDays {
            if day.date > range.end { continue }
            // Since allPresenceDays is reverse sorted by date, we can early exit once we pass the window
            if day.date < range.start { break }

            let isUnmodifiedDisputed = day.isDisputed && !day.isManuallyModified
            if isUnmodifiedDisputed {
                disputedCount += 1
            }

            if !isAnyFilterActive {
                matchingDays.append(day)
                continue
            }
            
            var matches = false
            
            if showUnknownOnly && day.countryCode == nil && day.countryName == nil {
                matches = true
            } else if showLowConfidenceOnly && day.confidenceLabel == .low {
                matches = true
            } else if showMediumConfidenceOnly && day.confidenceLabel == .medium {
                matches = true
            } else if showManualOnly && day.isManuallyModified {
                matches = true
            } else if showDisputedOnly && isUnmodifiedDisputed {
                matches = true
            }
            
            if matches {
                matchingDays.append(day)
            }
        }

        return (matchingDays, disputedCount)
    }

    var body: some View {
        let data = filteredData
        List {
            Section("Days") {
                if data.days.isEmpty {
                    ContentUnavailableView(
                        "No matching days",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No days match the active filters in the last two years.")
                    )
                } else {
                    ForEach(data.days) { day in
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
                    Toggle("Show Disputed (\(data.disputedCount))", isOn: $showDisputedOnly)
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
