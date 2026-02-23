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
        
        for day in presenceDays {
            guard let countryName = day.countryName ?? day.countryCode else { continue }
            let normalizedCode = CountryCodeNormalizer.normalize(day.countryCode)
            let key = normalizedCode ?? countryName
            
            if let info = countryDict[key] {
                countryDict[key] = CountryDaysInfo(
                    countryName: info.countryName,
                    countryCode: info.countryCode,
                    totalDays: info.totalDays + 1,
                    region: info.region
                )
            } else {
                countryDict[key] = CountryDaysInfo(
                    countryName: countryName,
                    countryCode: normalizedCode,
                    totalDays: 1,
                    region: normalizedCode.flatMap { SchengenMembers.isMember($0) ? .schengen : .nonSchengen } ?? .other
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
                SchengenSummarySection(summary: schengenSummary, unknownDays: unknownSchengenDays)
                CountriesListSection(countries: countryDaysSummary)
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
    
    init(countries: [CountryDaysInfo], warningThreshold: Int = 80) {
        self.countries = countries
        self.warningThreshold = warningThreshold
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visited Countries")
                .font(.system(.title2, design: .rounded).bold())
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
                        CountryDaysRow(info: info, warningThreshold: warningThreshold)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        
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
                Text("\(info.totalDays)")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(badgeColor)
                
                Text("days")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
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
    DashboardView()
        .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self], inMemory: true)
}
