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
    private static let logger = Logger(subsystem: "com.MCCANN.Learn", category: "ContentView")

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Stay.enteredOn, order: .reverse)]) private var stays: [Stay]
    @Query(sort: [SortDescriptor(\DayOverride.date, order: .reverse)]) private var overrides: [DayOverride]
    @Query(sort: [SortDescriptor(\PresenceDay.date, order: .reverse)]) private var presenceDays: [PresenceDay]
    @EnvironmentObject private var authManager: AuthenticationManager

    private var dataManager: DataManager {
        DataManager(modelContext: modelContext)
    }

    enum LedgerFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case unknown = "Unknown"
        case manual = "Manually Marked"
        var id: String { rawValue }
    }

    @State private var isPresentingAddStay = false
    @State private var isPresentingAddOverride = false
    @State private var isShowingSeedAlert = false
    @State private var schengenState = SchengenState()
    @State private var ledgerFilter: LedgerFilter = .all

    private var filteredPresenceDays: [PresenceDay] {
        switch ledgerFilter {
        case .all:
            return presenceDays
        case .unknown:
            return presenceDays.filter { day in
                day.countryCode == nil && day.countryName == nil
            }
        case .manual:
            return presenceDays.filter { $0.isOverride }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if schengenState.overlapCount > 0 || schengenState.gapDays > 0 {
                    Section("Data Quality") {
                        if schengenState.overlapCount > 0 {
                            Text("Overlapping stays detected: \(schengenState.overlapCount). Review overlaps or mark as transit days.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        if schengenState.gapDays > 0 {
                            Text("Gaps between stays: \(schengenState.gapDays) day(s). Consider adding stays or overrides.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
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

                    if filteredPresenceDays.isEmpty {
                        ContentUnavailableView(
                            "No ledger data",
                            systemImage: "calendar",
                            description: Text("No days match the selected filter.")
                        )
                    } else {
                        ForEach(filteredPresenceDays.prefix(5)) { day in
                            NavigationLink {
                                PresenceDayDetailView(day: day)
                            } label: {
                                PresenceDayRow(day: day)
                            }
                        }
                        
                        NavigationLink {
                            DailyLedgerView()
                        } label: {
                            Text("See All")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                } header: {
                    Text("Daily Ledger")
                }

                Section("Day Overrides") {
                    if overrides.isEmpty {
                        ContentUnavailableView(
                            "No overrides",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Add a day override to correct a specific date.")
                        )
                    } else {
                        ForEach(overrides) { overrideDay in
                            NavigationLink {
                                DayOverrideEditorView(overrideDay: overrideDay)
                            } label: {
                                DayOverrideRow(overrideDay: overrideDay)
                            }
                        }
                    }
                }

                Section("Stays") {
                    if stays.isEmpty {
                        ContentUnavailableView(
                            "No stays yet",
                            systemImage: "globe",
                            description: Text("Add your first stay to start tracking days.")
                        )
                    } else {
                        ForEach(stays) { stay in
                            NavigationLink {
                                StayEditorView(stay: stay)
                            } label: {
                                StayRow(stay: stay)
                            }
                        }
                        .onDelete(perform: deleteStays)
                    }
                }

                Section("Configuration") {
                    Text("Schengen membership: hard-coded (M1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            .navigationTitle("BorderLog")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Add Stay") {
                            isPresentingAddStay = true
                        }
                        Button("Add Day Override") {
                            isPresentingAddOverride = true
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }

            }
            .sheet(isPresented: $isPresentingAddStay) {
                NavigationStack {
                    StayEditorView()
                }
            }
            .sheet(isPresented: $isPresentingAddOverride) {
                NavigationStack {
                    DayOverrideEditorView()
                }
            }
        }
        .task(id: stays) {
            await schengenState.update(stays: stays, overrides: overrides)
            let recomputeService = LedgerRecomputeService(modelContainer: modelContext.container)
            await recomputeService.recomputeAll()
        }
        .task(id: overrides) {
            await schengenState.update(stays: stays, overrides: overrides)
            let recomputeService = LedgerRecomputeService(modelContainer: modelContext.container)
            await recomputeService.recomputeAll()
        }
        .task {
            let recomputeService = LedgerRecomputeService(modelContainer: modelContext.container)
            await recomputeService.recomputeAll()
        }
    }

    private func deleteStays(offsets: IndexSet) {
        dataManager.delete(offsets: offsets, from: stays)
    }

    private func deleteOverrides(offsets: IndexSet) {
        dataManager.delete(offsets: offsets, from: overrides)
    }

    private func resetAllData() {
        do {
            try dataManager.resetAllData()
        } catch {
            Self.logger.error("Failed to reset data: \(error, privacy: .public)")
        }
    }

    private func seedSampleData() {
        do {
            if try !dataManager.seedSampleData() {
                isShowingSeedAlert = true
            }
        } catch {
            Self.logger.error("Failed to seed data: \(error, privacy: .public)")
        }
    }
}

private struct StayRow: View {
    let stay: Stay

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(stay.displayTitle)
                    .font(.system(.headline, design: .rounded))

                if stay.isOngoing {
                    Text("Ongoing")
                        .font(.system(.caption, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            HStack {
                Text(dateRangeText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(stay.region.rawValue)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var dateRangeText: String {
        let formatter = Date.FormatStyle(date: .abbreviated, time: .omitted)
        let start = stay.enteredOn.formatted(formatter)
        if let exit = stay.exitedOn {
            return "\(start) - \(exit.formatted(formatter))"
        }
        return "\(start) - Present"
    }
}

private struct DayOverrideRow: View {
    let overrideDay: DayOverride

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(overrideDay.displayTitle)
                .font(.system(.headline, design: .rounded))

            HStack {
                Text(dateText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(overrideDay.region.rawValue)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var dateText: String {
        let formatter = Date.FormatStyle(date: .abbreviated, time: .omitted)
        return overrideDay.date.formatted(formatter)
    }
}




#Preview {
    ContentView()
        .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self], inMemory: true)
}
