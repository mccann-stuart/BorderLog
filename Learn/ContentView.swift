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
    @ObservedObject private var inferenceActivity = InferenceActivity.shared

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

    private var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .year, value: -2, to: today) ?? today
        return (start, today)
    }

    private var recentDayCount: Int {
        let range = dateRange
        return presenceDays.filter { day in
            day.date >= range.start && day.date <= range.end
        }.count
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
                        isPresentingAddOverride = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                    .accessibilityLabel("Add Day Override")
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

    private var rangeSummary: some View {
        let formatter = Date.FormatStyle(date: .abbreviated, time: .omitted)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Last 2 years", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(recentDayCount) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(dateRange.start.formatted(formatter)) – \(dateRange.end.formatted(formatter))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Evidence for this day appears below.")
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
