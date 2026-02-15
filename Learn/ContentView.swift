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
    @State private var isPresentingAdd = false

    private var schengenSummary: SchengenSummary {
        SchengenCalculator.summary(for: stays, asOf: Date())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SchengenSummaryRow(summary: schengenSummary)
                        .listRowSeparator(.hidden)
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
                                StayDetailView(stay: stay)
                            } label: {
                                StayRow(stay: stay)
                            }
                        }
                        .onDelete(perform: deleteStays)
                    }
                }
            }
            .navigationTitle("BorderLog")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAdd = true
                    } label: {
                        Label("Add Stay", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAdd) {
                StayEditorView()
            }
        }
    }

    private func deleteStays(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(stays[index])
        }
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
            return "\(start) – \(exit.formatted(formatter))"
        }
        return "\(start) – Present"
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

                if summary.overstayDays > 0 {
                    StatPill(title: "Over", value: "\(summary.overstayDays)d", tint: .red)
                } else {
                    StatPill(title: "Remaining", value: "\(summary.remainingDays)d", tint: .green)
                }
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
        return "Window: \(start) – \(end)"
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
        .modelContainer(for: Stay.self, inMemory: true)
}
