//
//  DashboardView.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: [SortDescriptor(\PresenceDay.date, order: .reverse)]) private var presenceDays: [PresenceDay]
    @Query private var countryConfigs: [CountryConfig]
    @ObservedObject private var inferenceActivity = InferenceActivity.shared
    @AppStorage("showSchengenDashboardSection") private var showSchengenDashboardSection = true
    @AppStorage(CountryDayCountingMode.storageKey, store: AppConfig.sharedDefaults) private var countryDayCountingModeRaw = CountryDayCountingMode.defaultMode.rawValue
    
    @State private var selectedTimeframe: VisitedCountriesTimeframe = .last12Months

    private var countryDayCountingMode: CountryDayCountingMode {
        CountryDayCountingMode.storedMode(from: countryDayCountingModeRaw)
    }
    
    private var schengenSummary: SchengenLedgerSummary {
        SchengenLedgerCalculator.summary(
            for: presenceDays,
            asOf: Date(),
            isReverseSorted: true,
            countingMode: countryDayCountingMode
        )
    }
    
    private var unknownSchengenDays: [PresenceDay] {
        let start = schengenSummary.windowStart
        let end = schengenSummary.windowEnd
        var unknownDays: [PresenceDay] = []

        // ⚡ Bolt: Since presenceDays is reverse chronologically sorted, we can early exit when reaching older dates
        for day in presenceDays {
            if day.date > end { continue }
            if day.date < start { break }
            if day.countedCountries(for: countryDayCountingMode).isEmpty {
                unknownDays.append(day)
            }
        }
        return unknownDays
    }

    private var visitedCountriesSummaryData: (countries: [CountryDaysInfo], unknownDays: [PresenceDay]) {
        var countryDict: [String: CountryDaysInfo] = [:]
        var unknownDays: [PresenceDay] = []
        let calendar = Calendar.current
        let now = Date()
        
        // ⚡ Bolt: Pre-calculate date range to allow early loop termination, turning O(N) into O(K) where K is days in timeframe.
        let dateRange = selectedTimeframe.dateRange(now: now, calendar: calendar)

        // ⚡ Bolt: Pre-compute dictionary of max allowed days to avoid O(N) lookup per country
        // Use reduce(into:) to eliminate intermediate array allocations from .map
        let configDict = countryConfigs.reduce(into: [String: Int](minimumCapacity: countryConfigs.count)) { dict, config in
            if dict[config.countryCode] == nil {
                dict[config.countryCode] = config.maxAllowedDays
            }
        }

        for day in presenceDays {
            // presenceDays is sorted reverse-chronologically (newest first).
            // If we've passed the oldest date in our timeframe range, we can stop evaluating entirely.
            if let range = dateRange, day.date < range.lowerBound {
                break
            }

            // For timeframes like "Last Year", skip days that are newer than the upper bound
            if let range = dateRange, day.date >= range.upperBound {
                continue
            }

            // Fallback for cases where dateRange couldn't be computed
            if dateRange == nil && !selectedTimeframe.contains(day.date, now: now, calendar: calendar) {
                continue
            }

            let countedCountries = day.countedCountries(for: countryDayCountingMode)
            if countedCountries.isEmpty {
                unknownDays.append(day)
                continue
            }

            for country in countedCountries {
                if countryDict[country.id] != nil {
                    // ⚡ Bolt: Mutate the struct in-place to avoid reallocating new IDs and structs during aggregation
                    countryDict[country.id]?.totalDays += 1
                } else {
                    let maxDays = configDict[country.countryCode ?? ""] ?? nil
                    countryDict[country.id] = CountryDaysInfo(
                        countryName: country.countryName,
                        countryCode: country.countryCode,
                        totalDays: 1,
                        region: Region(rawValue: country.regionRaw) ?? .other,
                        maxAllowedDays: maxDays
                    )
                }
            }
        }

        return (
            countries: countryDict.values.sorted { $0.totalDays > $1.totalDays },
            unknownDays: unknownDays
        )
    }
    
    var body: some View {
        let visitedSummary = visitedCountriesSummaryData
        let visitedCountryCodes = Set(visitedSummary.countries.compactMap(\.countryCode))

        ScrollView {
            VStack(spacing: 20) {
                WorldMapSection(visitedCountries: visitedCountryCodes)
                if inferenceActivity.isPhotoScanning ||
                    inferenceActivity.isCalendarScanning ||
                    inferenceActivity.isInferenceRunning ||
                    inferenceActivity.isLocationBatching ||
                    inferenceActivity.isGeoLookupPaused {
                    InferenceProgressSection(
                        photoScanned: inferenceActivity.photoScanScanned,
                        photoTotal: inferenceActivity.photoScanTotal,
                        calendarScanned: inferenceActivity.calendarScanScanned,
                        calendarTotal: inferenceActivity.calendarScanTotal,
                        inferenceProgress: inferenceActivity.inferenceProgress,
                        inferenceTotal: inferenceActivity.inferenceTotal,
                        isPhotoScanning: inferenceActivity.isPhotoScanning,
                        isCalendarScanning: inferenceActivity.isCalendarScanning,
                        isInferenceRunning: inferenceActivity.isInferenceRunning,
                        isLocationBatching: inferenceActivity.isLocationBatching,
                        isGeoLookupPaused: inferenceActivity.isGeoLookupPaused
                    )
                }
                if showSchengenDashboardSection {
                    SchengenSummarySection(summary: schengenSummary, unknownDays: unknownSchengenDays)
                }
                CountriesListSection(
                    countries: visitedSummary.countries,
                    unknownDays: visitedSummary.unknownDays,
                    selectedTimeframe: $selectedTimeframe
                )
            }
            .padding(.vertical)
        }
        .background(DashboardBackground())
    }
}

private struct DashboardBackground: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
            LinearGradient(colors: [.blue.opacity(0.05), .purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .ignoresSafeArea()
    }
}

private struct WorldMapSection: View {
    let visitedCountries: Set<String>
    
    var body: some View {
        WorldMapView(visitedCountries: visitedCountries)
            .frame(height: 250)
            .cardShell()
            .padding(.horizontal)
    }
}

private struct InferenceProgressSection: View {
    let photoScanned: Int
    let photoTotal: Int
    let calendarScanned: Int
    let calendarTotal: Int
    let inferenceProgress: Int
    let inferenceTotal: Int
    let isPhotoScanning: Bool
    let isCalendarScanning: Bool
    let isInferenceRunning: Bool
    let isLocationBatching: Bool
    let isGeoLookupPaused: Bool

    private var locationStatusText: String? {
        if isLocationBatching && isGeoLookupPaused {
            return "Paused: waiting for location batch and geo lookup capacity."
        }
        if isLocationBatching {
            return "Capturing location samples."
        }
        if isGeoLookupPaused {
            return "Paused: waiting for geo lookup capacity."
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inference progress")
                .font(.system(.headline, design: .rounded))

            ProgressRow(
                title: "Photos",
                systemImage: "photo",
                scanned: photoScanned,
                total: photoTotal,
                isActive: isPhotoScanning
            )

            ProgressRow(
                title: "Calendar",
                systemImage: "calendar",
                scanned: calendarScanned,
                total: calendarTotal,
                isActive: isCalendarScanning
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Location inference", systemImage: "location")
                        .font(.system(.subheadline, design: .rounded))
                    Spacer()
                    if isInferenceRunning {
                        Text(progressPercent(scanned: inferenceProgress, total: inferenceTotal))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                if isInferenceRunning {
                    ProgressView(value: progressFraction(scanned: inferenceProgress, total: inferenceTotal), total: 1)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                } else if locationStatusText != nil {
                    ProgressView()
                        .controlSize(.small)
                }
                if let locationStatusText {
                    Text(locationStatusText)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .cardShell()
        .padding(.horizontal)
    }

    private func progressFraction(scanned: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        let clamped = min(max(scanned, 0), total)
        return Double(clamped) / Double(total)
    }

    private func progressPercent(scanned: Int, total: Int) -> String {
        let fraction = progressFraction(scanned: scanned, total: total)
        return "\(Int((fraction * 100).rounded()))%"
    }
}

private struct ProgressRow: View {
    let title: String
    let systemImage: String
    let scanned: Int
    let total: Int
    let isActive: Bool

    private var progressFraction: Double {
        guard total > 0 else { return 0 }
        let clamped = min(max(scanned, 0), total)
        return Double(clamped) / Double(total)
    }

    private var percentText: String {
        "\(Int((progressFraction * 100).rounded()))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.system(.subheadline, design: .rounded))
                Spacer()
                Text(percentText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progressFraction, total: 1)
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .opacity(isActive ? 1 : 0.6)
        }
    }
}

private struct SchengenSummarySection: View {
    let summary: SchengenLedgerSummary
    let unknownDays: [PresenceDay]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Schengen")
                    .font(.system(.title2, design: .rounded).bold())
                Text("90 stays in a rolling 180 days")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Used",
                    value: "\(summary.usedDays)",
                    subtitle: "days",
                    color: .blue
                )
                
                StatCard(
                    title: "Remaining",
                    value: "\(summary.remainingDays)",
                    subtitle: "days",
                    color: .green
                )
                
                if summary.overstayDays > 0 {
                    StatCard(
                        title: "Overstay",
                        value: "\(summary.overstayDays)",
                        subtitle: "days",
                        color: .red
                    )
                }
            }

            if summary.unknownDays > 0 {
                NavigationLink {
                    FilteredLedgerView(days: unknownDays, title: "Unknown Days")
                } label: {
                    Text("Days with no location data: \(summary.unknownDays)")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .cardShell()
        .padding(.horizontal)
    }
}

private struct CountriesListSection: View {
    let countries: [CountryDaysInfo]
    let unknownDays: [PresenceDay]
    let warningThreshold: Int
    @Binding var selectedTimeframe: VisitedCountriesTimeframe
    
    init(
        countries: [CountryDaysInfo],
        unknownDays: [PresenceDay],
        warningThreshold: Int = 80,
        selectedTimeframe: Binding<VisitedCountriesTimeframe>
    ) {
        self.countries = countries
        self.unknownDays = unknownDays
        self.warningThreshold = warningThreshold
        self._selectedTimeframe = selectedTimeframe
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Visited Countries")
                    .font(.system(.title2, design: .rounded).bold())
                Spacer()
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(VisitedCountriesTimeframe.allCases) { tf in
                        Text(tf.rawValue).tag(tf)
                    }
                }
                .tint(.secondary)
            }
            .padding(.horizontal)
            
            if countries.isEmpty && unknownDays.isEmpty {
                ContentUnavailableView(
                    "No countries yet",
                    systemImage: "globe",
                    description: Text("Add your first stay to start tracking countries.")
                )
                .frame(height: 200)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(countries) { info in
                        NavigationLink(destination: CountryDetailView(
                            countryName: info.countryName,
                            countryCode: info.countryCode,
                            selectedTimeframe: selectedTimeframe
                        )) {
                            CountryDaysRow(info: info, warningThreshold: warningThreshold)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)

                        if info.id != countries.last?.id || !unknownDays.isEmpty {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }

                    if !unknownDays.isEmpty {
                        NavigationLink {
                            FilteredLedgerView(days: unknownDays, title: "Unknown Days")
                        } label: {
                            UnknownDaysSummaryRow(count: unknownDays.count)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .cardShell()
                .padding(.horizontal)
            }
        }
    }
}

struct UnknownDaysSummaryRow: View {
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "questionmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Unknown")
                    .font(.system(.headline, design: .rounded))
                Text("Days without a resolved location")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(count)d")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

// Stat card component
private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(color)
            
            Text(subtitle)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self, CountryConfig.self, CalendarSignal.self], inMemory: true)
    }
}
