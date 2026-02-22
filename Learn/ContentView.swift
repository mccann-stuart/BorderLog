//
//  ContentView.swift
//  Learn
//
//  Created by Mccann Stuart on 13/02/2026.
//

import SwiftUI
import SwiftData
import Foundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Stay.enteredOn, order: .reverse)]) private var stays: [Stay]
    @Query(sort: [SortDescriptor(\DayOverride.date, order: .reverse)]) private var overrides: [DayOverride]
    @Query(sort: [SortDescriptor(\PresenceDay.date, order: .reverse)]) private var presenceDays: [PresenceDay]

    private var dataManager: DataManager {
        DataManager(modelContext: modelContext)
    }

    @State private var isPresentingAddStay = false
    @State private var isPresentingAddOverride = false
    @State private var schengenState = SchengenState()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SchengenSummaryRow(summary: schengenState.summary)
                        .listRowSeparator(.hidden)
                }
                
                Section("Configuration") {
                    Text("Schengen membership: hard-coded (M1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

                Section("Daily Ledger") {
                    if presenceDays.isEmpty {
                        ContentUnavailableView(
                            "No ledger data",
                            systemImage: "calendar",
                            description: Text("Enable location or photo access to infer daily presence.")
                        )
                    } else {
                        ForEach(presenceDays.prefix(5)) { day in
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
                        .onDelete(perform: deleteOverrides)
                    }
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
            await schengenState.update(modelContext: modelContext)
            let recomputeService = LedgerRecomputeService(modelContainer: modelContext.container)
            await recomputeService.recomputeAll()
        }
        .task(id: overrides) {
            await schengenState.update(modelContext: modelContext)
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



private struct SchengenSummaryRow: View {
    let summary: SchengenSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Schengen 90/180")
                .font(.system(.headline, design: .rounded))

            HStack(spacing: 12) {
                StatPill(title: "Used", value: "\(summary.usedDays)d")
                StatPill(title: "Remaining", value: "\(summary.remainingDays)d", tint: .green)
                StatPill(title: "Overstay", value: "\(summary.overstayDays)d", tint: .red)
            }

            Text(windowText)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var windowText: String {
        let formatter = Date.FormatStyle(date: .abbreviated, time: .omitted)
        let start = summary.windowStart.formatted(formatter)
        let end = summary.windowEnd.formatted(formatter)
        return "Window: \(start) - \(end)"
    }
}

private struct StatPill: View {
    let title: String
    let value: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.headline, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self], inMemory: true)
}
