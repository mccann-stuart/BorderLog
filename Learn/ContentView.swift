//
//  ContentView.swift
//  Learn
//
//  Created by Mccann Stuart on 13/02/2026.
//

import SwiftUI
import SwiftData
import Foundation
import os

struct ContentView: View {
    private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "ContentView")

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\DayOverride.date, order: .reverse)]) private var overrides: [DayOverride]
    @Query(sort: [SortDescriptor(\Stay.enteredOn, order: .reverse)]) private var stays: [Stay]
    @Query(sort: [SortDescriptor(\PresenceDay.date, order: .reverse)]) private var presenceDays: [PresenceDay]
    @EnvironmentObject private var authManager: AuthenticationManager
    @ObservedObject private var inferenceActivity = InferenceActivity.shared

    private var dataManager: DataManager {
        DataManager(modelContext: modelContext)
    }

    enum LedgerFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case unknown = "Unknown"
        case manual = "Manually Marked"
        case disputed = "Disputed"
        var id: String { rawValue }
    }

    @State private var isPresentingAddStay = false
    @State private var isShowingSeedAlert = false
    @State private var schengenState = SchengenState()
    @State private var ledgerFilter: LedgerFilter = .all

    private var previewPresenceDays: [PresenceDay] {
        switch ledgerFilter {
        case .all:
            return Array(presenceDays.prefix(5))
        case .unknown:
            return Array(presenceDays.lazy.filter { day in
                day.countryCode == nil && day.countryName == nil
            }.prefix(5))
        case .manual:
            return Array(presenceDays.lazy.filter { $0.isManuallyModified }.prefix(5))
        case .disputed:
            return Array(presenceDays.lazy.filter { $0.isDisputed && !$0.isManuallyModified }.prefix(5))
        }
    }

    private var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .year, value: -2, to: today) ?? today
        return (start, today)
    }

    // ⚡ Bolt: Single-pass iteration to calculate metrics in O(K) time and O(1) space
    private var ledgerMetrics: (recentCount: Int, disputedCount: Int) {
        let range = dateRange
        var recentCount = 0
        var disputedCount = 0

        for day in presenceDays {
            // Since presenceDays is reverse sorted by date, skip future days
            if day.date > range.end { continue }
            // Early exit once we pass the 2-year window
            if day.date < range.start { break }

            recentCount += 1
            if day.isDisputed && !day.isManuallyModified {
                disputedCount += 1
            }
        }

        return (recentCount, disputedCount)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    rangeSummary
                    activityStatus
                }

                Section {
                    Picker("Filter Ledger", selection: $ledgerFilter) {
                        ForEach(LedgerFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.bottom, 8)

                    if previewPresenceDays.isEmpty {
                        ContentUnavailableView(
                            "No ledger data",
                            systemImage: "calendar",
                            description: Text("No days match the selected filter.")
                        )
                    } else {
                        ForEach(previewPresenceDays) { day in
                            NavigationLink {
                                PresenceDayDetailView(day: day)
                            } label: {
                                PresenceDayRow(day: day)
                            }
                        }
                        
                        NavigationLink {
                            DailyLedgerView(initialFilter: {
                                switch ledgerFilter {
                                case .unknown: return .unknown
                                case .manual: return .manual
                                case .disputed: return .disputed
                                case .all: return .none
                                }
                            }())
                        } label: {
                            Text("See All")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                } header: {
                    Text("Daily Ledger")
                }



            }
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    Color(UIColor.systemGroupedBackground)
                    LinearGradient(colors: [.blue.opacity(0.05), .purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Daily Ledger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresentingAddStay = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                    .accessibilityLabel("Add Stay")
                }
            }
            .sheet(isPresented: $isPresentingAddStay) {
                NavigationStack {
                    StayEditorView()
                }
            }
        }
        .task(id: overrides) {
            await refreshLedger()
        }
        .task(id: stays) {
            await refreshLedger()
        }
    }

    private var rangeSummary: some View {
        let formatter = Date.FormatStyle(date: .abbreviated, time: .omitted)
        let metrics = ledgerMetrics
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Last 2 years", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(metrics.recentCount) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(dateRange.start.formatted(formatter)) – \(dateRange.end.formatted(formatter))")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Label("Disputed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(metrics.disputedCount > 0 ? Color.orange : Color.secondary)
                Spacer()
                Text("\(metrics.disputedCount)")
                    .foregroundStyle(metrics.disputedCount > 0 ? Color.orange : Color.secondary)
            }
            .font(.caption)
            Text("Click each day for evidence of location")
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


    private func deleteOverrides(offsets: IndexSet) {
        dataManager.delete(offsets: offsets, from: overrides)
    }

    private func resetAllData() {
        do {
            try dataManager.resetAllData()
        } catch {
            Self.logger.error("Failed to reset data: \(error, privacy: .private)")
        }
    }

    @MainActor
    private func refreshLedger() async {
        await schengenState.update(stays: stays, overrides: overrides)
        let recomputeService = LedgerRecomputeService(modelContainer: modelContext.container)
        await recomputeService.recomputeAll()
    }

    private func seedSampleData() {
        do {
            if try !dataManager.seedSampleData() {
                isShowingSeedAlert = true
            }
        } catch {
            Self.logger.error("Failed to seed data: \(error, privacy: .private)")
        }
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
    ContentView()
        .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self, CalendarSignal.self], inMemory: true)
}
