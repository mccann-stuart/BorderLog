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
}

struct DailyLedgerView: View {
    @Query(sort: [SortDescriptor(\PresenceDay.date, order: .reverse)]) private var allPresenceDays: [PresenceDay]
    @ObservedObject private var inferenceActivity = InferenceActivity.shared
    
    var initialFilter: LedgerPreFilter = .none
    
    @State private var showUnknownOnly = false
    @State private var showLowConfidenceOnly = false
    @State private var showMediumConfidenceOnly = false
    @State private var showManualOnly = false
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
        showUnknownOnly || showLowConfidenceOnly || showMediumConfidenceOnly || showManualOnly
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
                if day.isOverride {
                    matches = true
                }
            }
            
            return matches
        }
    }

    var body: some View {
        List {
            Section {
                rangeSummary
                activityStatus
            }

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
                        }
                    }
                    Toggle("Show Unknown", isOn: $showUnknownOnly)
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
            }
        }
    }

    private var rangeSummary: some View {
        let formatter = Date.FormatStyle(date: .abbreviated, time: .omitted)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Last 2 years", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(filteredDays.count) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(dateRange.start.formatted(formatter)) – \(dateRange.end.formatted(formatter))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Newest first. Tap a day for evidence.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var activityStatus: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ActivityBadge(
                    title: "Photo scanning",
                    systemImage: "photo",
                    isActive: inferenceActivity.isPhotoScanning
                )
                ActivityBadge(
                    title: "Location inference",
                    systemImage: "location",
                    isActive: inferenceActivity.isInferenceRunning
                )
            }
            VStack(alignment: .leading, spacing: 8) {
                ActivityBadge(
                    title: "Photo scanning",
                    systemImage: "photo",
                    isActive: inferenceActivity.isPhotoScanning
                )
                ActivityBadge(
                    title: "Location inference",
                    systemImage: "location",
                    isActive: inferenceActivity.isInferenceRunning
                )
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ActivityBadge: View {
    let title: String
    let systemImage: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
            if isActive {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.1))
        .foregroundStyle(isActive ? .primary : .secondary)
        .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        DailyLedgerView(initialFilter: .unknown)
            .modelContainer(for: [PresenceDay.self], inMemory: true)
    }
}
