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
    
    @State private var selectedTimeframe: VisitedCountriesTimeframe = .last12Months
    
    private var timeframeDays: [PresenceDay] {
        let calendar = Calendar.current
        let now = Date()
        return presenceDays.filter { day in
            selectedTimeframe.contains(day.date, now: now, calendar: calendar)
        }
    }
    
    private var schengenSummary: SchengenLedgerSummary {
        SchengenLedgerCalculator.summary(for: presenceDays, asOf: Date())
    }
    
    private var unknownSchengenDays: [PresenceDay] {
        let start = schengenSummary.windowStart
        let end = schengenSummary.windowEnd
        return presenceDays.filter { day in
            day.date >= start && day.date <= end &&
            (day.countryCode == nil && day.countryName == nil)
        }
    }
    
    // Group stays by country and calculate total days
    private var countryDaysSummary: [CountryDaysInfo] {
        var countryDict: [String: CountryDaysInfo] = [:]
        
        for day in timeframeDays {
            guard let countryName = day.countryName ?? day.countryCode else { continue }
            let normalizedCode = CountryCodeNormalizer.normalize(day.countryCode)
            let key = normalizedCode ?? countryName

            if let info = countryDict[key] {
                countryDict[key] = CountryDaysInfo(
                    countryName: info.countryName,
                    countryCode: info.countryCode,
                    totalDays: info.totalDays + 1,
                    region: info.region,
                    maxAllowedDays: info.maxAllowedDays
                )
            } else {
                let maxDays = countryConfigs.first { $0.countryCode == (normalizedCode ?? "") }?.maxAllowedDays
                countryDict[key] = CountryDaysInfo(
                    countryName: countryName,
                    countryCode: normalizedCode,
                    totalDays: 1,
                    region: normalizedCode.flatMap { SchengenMembers.isMember($0) ? .schengen : .nonSchengen } ?? .other,
                    maxAllowedDays: maxDays
                )
            }
        }

        return countryDict.values.sorted { $0.totalDays > $1.totalDays }
    }

    private var visitedCountryCodes: Set<String> {
        Set(countryDaysSummary.compactMap(\.countryCode))
    }
    
    var body: some View {
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
                CountriesListSection(countries: countryDaysSummary, selectedTimeframe: $selectedTimeframe)
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
            Text("Schengen 90/180")
                .font(.system(.title2, design: .rounded).bold())
            
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
                    Text("Unknown days in window: \(summary.unknownDays)")
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
    let warningThreshold: Int
    @Binding var selectedTimeframe: VisitedCountriesTimeframe
    
    init(countries: [CountryDaysInfo], warningThreshold: Int = 80, selectedTimeframe: Binding<VisitedCountriesTimeframe>) {
        self.countries = countries
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
            
            if countries.isEmpty {
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

                            if info.id != countries.last?.id {
                                Divider()
                                    .padding(.leading, 60)
                            }
                    }
                }
                .cardShell()
                .padding(.horizontal)
            }
        }
    }
}

private struct CardShell: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
    }
}

private extension View {
    func cardShell() -> some View {
        modifier(CardShell())
    }
}

// Helper struct for country summary
struct CountryDaysInfo: Identifiable {
    let id = UUID()
    let countryName: String
    let countryCode: String?
    var totalDays: Int
    let region: Region
    var maxAllowedDays: Int?

    var flagEmoji: String {
        guard let code = countryCode?.uppercased() else { return "🌍" }
        return countryCodeToEmoji(code)
    }
}

// Convert ISO country code to flag emoji
private func countryCodeToEmoji(_ code: String) -> String {
    let base: UInt32 = 127397
    var emoji = ""
    let normalized = CountryCodeNormalizer.normalize(code) ?? code.uppercased()
    for scalar in normalized.unicodeScalars {
        if let unicodeScalar = UnicodeScalar(base + scalar.value) {
            emoji.append(String(unicodeScalar))
        }
    }
    return emoji.isEmpty ? "🌍" : emoji
}

// Country row component
private struct CountryDaysRow: View {
    let info: CountryDaysInfo
    let warningThreshold: Int
    
    private var backgroundColor: Color {
        if info.totalDays >= 90 {
            return .red.opacity(0.15)
        } else if info.totalDays >= warningThreshold {
            return .yellow.opacity(0.15)
        }
        return .clear
    }
    
    private var badgeColor: Color {
        if info.totalDays >= 90 {
            return .red
        } else if info.totalDays >= warningThreshold {
            return .orange
        }
        return .secondary
    }

    private func daysAttributedText(maxDays: Int) -> AttributedString {
        var daysText = AttributedString("\(info.totalDays) of \(maxDays)")
        if let range = daysText.range(of: "\(info.totalDays)") {
            daysText[range].foregroundColor = badgeColor
        }
        if let range = daysText.range(of: " of \(maxDays)") {
            daysText[range].foregroundColor = .secondary
        }
        return daysText
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(info.flagEmoji)
                .font(.system(size: 40))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(info.countryName)
                    .font(.system(.headline, design: .rounded))
                
                Text(info.region.rawValue)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if let maxDays = info.maxAllowedDays {
                    Text(daysAttributedText(maxDays: maxDays))
                        .font(.system(.title2, design: .rounded).bold())

                    Text("allowed days".uppercased())
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(info.totalDays)")
                        .font(.system(.title2, design: .rounded).bold())
                        .foregroundStyle(badgeColor)

                    Text("days".uppercased())
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
