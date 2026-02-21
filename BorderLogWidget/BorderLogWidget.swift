//
//  BorderLogWidget.swift
//  BorderLogWidget
//
//  Created by Mccann Stuart on 16/02/2026.
//

import WidgetKit
import SwiftUI
import SwiftData

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
            _ = await service.captureAndStoreBurst(
                source: .widget,
                modelContext: modelContext,
                maxSamples: 6,
                maxDuration: 8,
                maxSampleAge: 120
            )

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
                .font(.headline)

            Text(entry.country)
                .font(.title2.bold())

            if let timestamp = entry.timestamp {
                Text(timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No recent sample")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

@main
struct BorderLogWidget: Widget {
    let kind: String = "BorderLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BorderLogWidgetProvider()) { entry in
            BorderLogWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("BorderLog")
        .description("Logs your current country when the widget refreshes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
