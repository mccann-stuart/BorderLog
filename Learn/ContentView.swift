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
                            DailyLedgerView(initialFilter: {
                                switch ledgerFilter {
                                case .unknown: return .unknown
                                case .manual: return .manual
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
                    Button {
                        isPresentingAddOverride = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }

            }
            .sheet(isPresented: $isPresentingAddOverride) {
                NavigationStack {
                    DayOverrideEditorView()
                }
            }
        }
        .task(id: overrides) {
            await schengenState.update(stays: [], overrides: overrides)
            let recomputeService = LedgerRecomputeService(modelContainer: modelContext.container)
            await recomputeService.recomputeAll()
        }
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








#Preview {
    ContentView()
        .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self], inMemory: true)
}
