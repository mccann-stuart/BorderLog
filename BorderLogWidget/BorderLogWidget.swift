//
//  BorderLogWidget.swift
//  BorderLogWidget
//
//  Created by Mccann Stuart on 16/02/2026.
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Widget Bundle
@main
struct BorderLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        BorderLogWidget()
        TopCountriesWidget()
        SchengenWidget()
    }
}

// MARK: - BorderLogWidget (Current Location)

struct BorderLogWidgetEntry: TimelineEntry {
    let date: Date
    let country: String
    let timestamp: Date?
}

struct BorderLogWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BorderLogWidgetEntry {
        BorderLogWidgetEntry(date: Date(), country: "Last known", timestamp: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (BorderLogWidgetEntry) -> Void) {
        completion(BorderLogWidgetEntry(date: Date(), country: "Last known", timestamp: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BorderLogWidgetEntry>) -> Void) {
        Task { @MainActor in
            let container = ModelContainerProvider.makeContainer()
            let modelContext = ModelContext(container)

            let service = LocationSampleService()
            do {
                _ = try await service.captureAndStoreBurst(
                    source: .widget,
                    modelContext: modelContext,
                    maxSamples: 6,
                    maxDuration: 8,
                    maxSampleAge: 120
                )
            } catch {
                // Keep widget timeline generation resilient if capture/persistence fails.
            }

            let latest = Self.latestSample(from: modelContext)
            let country = latest?.countryName ?? latest?.countryCode ?? "Unknown"
            let entry = BorderLogWidgetEntry(date: Date(), country: country, timestamp: latest?.timestamp)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private static func latestSample(from modelContext: ModelContext) -> LocationSample? {
        var descriptor = FetchDescriptor<LocationSample>(sortBy: [SortDescriptor(\LocationSample.timestamp, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }
}

struct BorderLogWidgetEntryView: View {
    var entry: BorderLogWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BorderLog")
                .font(.system(.headline, design: .rounded))

            Text(entry.country)
                .font(.system(.title2, design: .rounded).bold())

            if let timestamp = entry.timestamp {
                Text(timestamp, style: .time)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text("No recent sample")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }
}

struct BorderLogWidget: Widget {
    let kind: String = "BorderLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BorderLogWidgetProvider()) { entry in
            BorderLogWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Current Location")
        .description("Logs your current country when the widget refreshes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Top Countries Widget

struct WidgetCountryDaysInfo: Identifiable {
    let id = UUID()
    let countryName: String
    let countryCode: String?
    var totalDays: Int
    let region: Region
}

struct TopCountriesEntry: TimelineEntry {
    let date: Date
    let topCountries: [WidgetCountryDaysInfo]
}

struct TopCountriesWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TopCountriesEntry {
        TopCountriesEntry(date: Date(), topCountries: [
            WidgetCountryDaysInfo(countryName: "France", countryCode: "FR", totalDays: 42, region: .schengen),
            WidgetCountryDaysInfo(countryName: "Spain", countryCode: "ES", totalDays: 14, region: .schengen),
            WidgetCountryDaysInfo(countryName: "United Kingdom", countryCode: "GB", totalDays: 7, region: .nonSchengen)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (TopCountriesEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TopCountriesEntry>) -> Void) {
        Task {
            let container = ModelContainerProvider.makeContainer()
            let modelContext = ModelContext(container)

            var descriptor = FetchDescriptor<PresenceDay>()
            let now = Date()
            guard let startOfYear = Calendar.current.dateInterval(of: .year, for: now)?.start else {
                let timeline = Timeline(entries: [TopCountriesEntry(date: now, topCountries: [])], policy: .after(now.addingTimeInterval(3600)))
                completion(timeline)
                return
            }

            // In SwiftData, predicate filters can be tricky. We can fetch all and filter or use a predicate.
            // PresenceDay has a `date` property.
            descriptor.predicate = #Predicate<PresenceDay> { day in
                day.date >= startOfYear
            }

            let presenceDays = (try? modelContext.fetch(descriptor)) ?? []

            var countryDict: [String: WidgetCountryDaysInfo] = [:]
            for day in presenceDays {
                guard let countryName = day.countryName ?? day.countryCode else { continue }
                let normalizedCode = CountryCodeNormalizer.normalize(day.countryCode)
                let key = normalizedCode ?? countryName
                
                if let info = countryDict[key] {
                    countryDict[key] = WidgetCountryDaysInfo(
                        countryName: info.countryName,
                        countryCode: info.countryCode,
                        totalDays: info.totalDays + 1,
                        region: info.region
                    )
                } else {
                    countryDict[key] = WidgetCountryDaysInfo(
                        countryName: countryName,
                        countryCode: normalizedCode,
                        totalDays: 1,
                        region: normalizedCode.flatMap { SchengenMembers.isMember($0) ? .schengen : .nonSchengen } ?? .other
                    )
                }
            }

            let sorted = countryDict.values.sorted { $0.totalDays > $1.totalDays }
            let top3 = Array(sorted.prefix(3))

            let entry = TopCountriesEntry(date: now, topCountries: top3)
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 3, to: now) ?? now.addingTimeInterval(10800)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
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

struct TopCountriesWidgetEntryView: View {
    var entry: TopCountriesWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top Countries")
                .font(.system(.headline, design: .rounded))
            
            if entry.topCountries.isEmpty {
                Text("No data this year")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                let limit = family == .systemSmall ? 2 : 3
                ForEach(entry.topCountries.prefix(limit)) { info in
                    HStack {
                        Text(countryCodeToEmoji(info.countryCode ?? ""))
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text(info.countryName)
                                .font(.system(.subheadline, design: .rounded).bold())
                                .lineLimit(1)
                            Text("\(info.totalDays) days")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}

struct TopCountriesWidget: Widget {
    let kind: String = "TopCountriesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TopCountriesWidgetProvider()) { entry in
            TopCountriesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Top Countries")
        .description("Shows your top visited countries this year.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Schengen Widget

struct SchengenEntry: TimelineEntry {
    let date: Date
    let summary: SchengenLedgerSummary
}

struct SchengenWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SchengenEntry {
        let dummySummary = SchengenLedgerSummary(
            usedDays: 45,
            remainingDays: 45,
            overstayDays: 0,
            unknownDays: 2,
            windowStart: Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? Date(),
            windowEnd: Date()
        )
        return SchengenEntry(date: Date(), summary: dummySummary)
    }

    func getSnapshot(in context: Context, completion: @escaping (SchengenEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SchengenEntry>) -> Void) {
        Task {
            let container = ModelContainerProvider.makeContainer()
            let modelContext = ModelContext(container)
            
            let now = Date()
            let windowStart = Calendar.current.date(byAdding: .day, value: -180, to: now) ?? now.addingTimeInterval(-180 * 24 * 3600)
            
            var descriptor = FetchDescriptor<PresenceDay>()
            descriptor.predicate = #Predicate<PresenceDay> { day in
                day.date >= windowStart
            }
            
            let days = (try? modelContext.fetch(descriptor)) ?? []
            let summary = SchengenLedgerCalculator.summary(for: days, asOf: now)
            
            let entry = SchengenEntry(date: now, summary: summary)
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 3, to: now) ?? now.addingTimeInterval(10800)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

struct SchengenWidgetEntryView: View {
    var entry: SchengenWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Schengen 90/180")
                .font(.system(.headline, design: .rounded))
            
            if family == .systemSmall {
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(entry.summary.usedDays)")
                            .font(.system(.title2, design: .rounded).bold())
                            .foregroundStyle(.blue)
                        Text("Used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(entry.summary.remainingDays)")
                            .font(.system(.title2, design: .rounded).bold())
                            .foregroundStyle(.green)
                        Text("Left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if entry.summary.overstayDays > 0 {
                    Text("\(entry.summary.overstayDays) days overstay")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red)
                        .clipShape(Capsule())
                }
            } else {
                HStack(spacing: 16) {
                    VStack {
                        Text("\(entry.summary.usedDays)")
                            .font(.system(.title, design: .rounded).bold())
                            .foregroundStyle(.blue)
                        Text("Used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack {
                        Text("\(entry.summary.remainingDays)")
                            .font(.system(.title, design: .rounded).bold())
                            .foregroundStyle(.green)
                        Text("Remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    if entry.summary.overstayDays > 0 {
                        VStack {
                            Text("\(entry.summary.overstayDays)")
                                .font(.system(.title, design: .rounded).bold())
                                .foregroundStyle(.red)
                            Text("Overstay")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                if entry.summary.unknownDays > 0 {
                    Text("Unknown days in window: \(entry.summary.unknownDays)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}

struct SchengenWidget: Widget {
    let kind: String = "SchengenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SchengenWidgetProvider()) { entry in
            SchengenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Schengen Glance")
        .description("Track your Schengen allowance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
