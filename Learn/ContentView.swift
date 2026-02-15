//
//  ContentView.swift
//  Learn
//
//  Created by Mccann Stuart on 13/02/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Stay.enteredOn, order: .reverse)]) private var stays: [Stay]
    @Query(sort: [SortDescriptor(\DayOverride.date, order: .reverse)]) private var overrides: [DayOverride]
    @AppStorage("appleUserId") private var appleUserId: String = ""

    @State private var isPresentingAddStay = false
    @State private var isPresentingAddOverride = false
    @State private var isConfirmingReset = false
    @State private var isShowingSeedAlert = false

    private var schengenSummary: SchengenSummary {
        SchengenCalculator.summary(for: stays, overrides: overrides, asOf: Date())
    }

    private var overlapCount: Int {
        StayValidation.overlapCount(stays: stays, calendar: .current)
    }

    private var gapDays: Int {
        StayValidation.gapDays(stays: stays, calendar: .current)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SchengenSummaryRow(summary: schengenSummary)
                        .listRowSeparator(.hidden)
                }

                if overlapCount > 0 || gapDays > 0 {
                    Section("Data Quality") {
                        if overlapCount > 0 {
                            Text("Overlapping stays detected: \(overlapCount). Review overlaps or mark as transit days.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        if gapDays > 0 {
                            Text("Gaps between stays: \(gapDays) day(s). Consider adding stays or overrides.")
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

                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button("Seed Sample Data") {
                            seedSampleData()
                        }

                        Button("Reset All Data", role: .destructive) {
                            isConfirmingReset = true
                        }

                        Divider()

                        Button("Sign Out") {
                            appleUserId = ""
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog("Delete all local data?", isPresented: $isConfirmingReset) {
                Button("Delete All", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will remove all stays and day overrides from this device.")
            }
            .alert("Sample data unavailable", isPresented: $isShowingSeedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Reset all data before seeding the sample dataset.")
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
    }

    private func deleteStays(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(stays[index])
        }
    }

    private func deleteOverrides(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(overrides[index])
        }
    }

    private func resetAllData() {
        stays.forEach { modelContext.delete($0) }
        overrides.forEach { modelContext.delete($0) }
    }

    private func seedSampleData() {
        guard stays.isEmpty && overrides.isEmpty else {
            isShowingSeedAlert = true
            return
        }

        SampleData.seed(context: modelContext)
    }
}

private struct StayRow: View {
    let stay: Stay

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(stay.displayTitle)
                    .font(.headline)

                if stay.isOngoing {
                    Text("Ongoing")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            HStack {
                Text(dateRangeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(stay.region.rawValue)
                    .font(.caption)
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
                .font(.headline)

            HStack {
                Text(dateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(overrideDay.region.rawValue)
                    .font(.caption)
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
                .font(.headline)

            HStack(spacing: 12) {
                StatPill(title: "Used", value: "\(summary.usedDays)d")
                StatPill(title: "Remaining", value: "\(summary.remainingDays)d", tint: .green)
                StatPill(title: "Overstay", value: "\(summary.overstayDays)d", tint: .red)
            }

            Text(windowText)
                .font(.caption)
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
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Stay.self, DayOverride.self], inMemory: true)
}
