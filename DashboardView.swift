//
//  DashboardView.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Stay.enteredOn, order: .reverse)]) private var stays: [Stay]
    @Query(sort: [SortDescriptor(\DayOverride.date, order: .reverse)]) private var overrides: [DayOverride]
    
    private var schengenSummary: SchengenSummary {
        SchengenCalculator.summary(for: stays, overrides: overrides, asOf: Date())
    }
    
    // Group stays by country and calculate total days
    private var countryDaysSummary: [CountryDaysInfo] {
        var countryDict: [String: CountryDaysInfo] = [:]
        
        for stay in stays {
            let days = stay.durationInDays()
            let key = stay.countryCode ?? stay.countryName
            
            if let info = countryDict[key] {
                countryDict[key] = CountryDaysInfo(
                    countryName: info.countryName,
                    countryCode: info.countryCode,
                    totalDays: info.totalDays + days,
                    region: info.region
                )
            } else {
                countryDict[key] = CountryDaysInfo(
                    countryName: stay.countryName,
                    countryCode: stay.countryCode,
                    totalDays: days,
                    region: stay.region
                )
            }
        }
        
        return countryDict.values.sorted { $0.totalDays > $1.totalDays }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // World Map Section
                WorldMapView(visitedCountries: Set(countryDaysSummary.compactMap { $0.countryCode }))
                    .frame(height: 250)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                
                // Schengen Summary Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Schengen 90/180")
                        .font(.title2.bold())
                    
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Used",
                            value: "\(schengenSummary.usedDays)",
                            subtitle: "days",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "Remaining",
                            value: "\(schengenSummary.remainingDays)",
                            subtitle: "days",
                            color: .green
                        )
                        
                        if schengenSummary.overstayDays > 0 {
                            StatCard(
                                title: "Overstay",
                                value: "\(schengenSummary.overstayDays)",
                                subtitle: "days",
                                color: .red
                            )
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                .padding(.horizontal)
                
                // Countries List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Visited Countries")
                        .font(.title2.bold())
                        .padding(.horizontal)
                    
                    if countryDaysSummary.isEmpty {
                        ContentUnavailableView(
                            "No countries yet",
                            systemImage: "globe",
                            description: Text("Add your first stay to start tracking countries.")
                        )
                        .frame(height: 200)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(countryDaysSummary) { info in
                                CountryDaysRow(info: info, warningThreshold: 80)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                
                                if info.id != countryDaysSummary.last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(UIColor.secondarySystemBackground))
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
    for scalar in code.uppercased().unicodeScalars {
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
                    .font(.headline)
                
                Text(info.region.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(info.totalDays)")
                    .font(.title2.bold())
                    .foregroundStyle(badgeColor)
                
                Text("days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color)
            
            Text(subtitle)
                .font(.caption2)
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
        .modelContainer(for: [Stay.self, DayOverride.self], inMemory: true)
}
