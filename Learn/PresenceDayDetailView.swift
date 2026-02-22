//
//  PresenceDayDetailView.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import SwiftUI
import SwiftData

struct PresenceDayDetailView: View {
    let day: PresenceDay

    @State private var isShowingOverride = false

    private var dayTitle: String {
        day.dayKey
    }

    private var countryText: String {
        if let name = day.countryName ?? day.countryCode {
            return name
        }
        return "Unknown"
    }

    private var confidenceText: String {
        day.confidenceLabel.rawValue.capitalized
    }

    var body: some View {
        Form {
            Section("Summary") {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(dayTitle)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Country")
                    Spacer()
                    Text(countryText)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Confidence")
                    Spacer()
                    Text(confidenceText)
                        .foregroundStyle(.secondary)
                }

                if day.isOverride {
                    Text("This day has a manual override and will always win.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            EvidenceSection(dayKey: day.dayKey, date: day.date)

            Section("Actions") {
                Button("Override Day") {
                    isShowingOverride = true
                }
            }
        }
        .navigationTitle("Day Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingOverride) {
            NavigationStack {
                DayOverrideEditorView(
                    overrideDay: nil,
                    presetDate: day.date,
                    presetCountryName: day.countryName,
                    presetCountryCode: day.countryCode
                )
            }
        }
    }
}


private struct EvidenceSection: View {
    let dayKey: String
    let date: Date
    
    @Environment(\.modelContext) private var modelContext

    @State private var locations: [LocationSample] = []
    @State private var photos: [PhotoSignal] = []
    @State private var stays: [Stay] = []
    
    init(dayKey: String, date: Date) {
        self.dayKey = dayKey
        self.date = date
    }
    
    var body: some View {
        Group {
            Section("Stays (\(stays.count))") {
                if stays.isEmpty {
                    Text("No matching stays")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(stays) { stay in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stay.countryName)
                                .font(.headline)
                            Text(dateRangeText(for: stay))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Photos (\(photos.count))") {
                if photos.isEmpty {
                    Text("No photo evidence")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(photos) { photo in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(photo.countryName ?? photo.countryCode ?? "Unknown Location")
                                .font(.subheadline)
                            HStack {
                                Text(photo.timestamp.formatted(date: .omitted, time: .shortened))
                                Spacer()
                                Text(String(format: "%.4f, %.4f", photo.latitude, photo.longitude))
                                    .font(.caption2)
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Location Samples (\(locations.count))") {
                if locations.isEmpty {
                    Text("No location samples")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(locations) { loc in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(loc.countryName ?? loc.countryCode ?? "Unknown Location")
                                    .font(.subheadline)
                                Spacer()
                                Text(loc.source.rawValue.capitalized)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            HStack {
                                Text(loc.timestamp.formatted(date: .omitted, time: .shortened))
                                Spacer()
                                Text(String(format: "%.4f, %.4f (±%.0fm)", loc.latitude, loc.longitude, loc.accuracyMeters))
                                    .font(.caption2)
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear { loadData() }
        .onChange(of: dayKey) { loadData() }
        .onChange(of: date) { loadData() }
    }
    
    private func loadData() {
        // Locations for this dayKey, sorted by timestamp
        do {
            let locPredicate = #Predicate<LocationSample> { target in
                target.dayKey == dayKey
            }
            var locFetch = FetchDescriptor<LocationSample>(predicate: locPredicate)
            locFetch.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
            locations = try modelContext.fetch(locFetch)
        } catch {
            locations = []
        }

        // Photos for this dayKey, sorted by timestamp
        do {
            let photoPredicate = #Predicate<PhotoSignal> { target in
                target.dayKey == dayKey
            }
            var photoFetch = FetchDescriptor<PhotoSignal>(predicate: photoPredicate)
            photoFetch.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
            photos = try modelContext.fetch(photoFetch)
        } catch {
            photos = []
        }

        // Stays sorted by enteredOn, reverse order
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        if let nextDayStart = calendar.date(byAdding: .day, value: 1, to: startOfDay) {
            do {
                let distantFuture = Date.distantFuture
                let stayPredicate = #Predicate<Stay> { stay in
                    stay.enteredOn < nextDayStart && (stay.exitedOn ?? distantFuture) >= startOfDay
                }
                var stayFetch = FetchDescriptor<Stay>(predicate: stayPredicate)
                stayFetch.sortBy = [SortDescriptor(\.enteredOn, order: .reverse)]
                stays = try modelContext.fetch(stayFetch)
            } catch {
                stays = []
            }
        } else {
            stays = []
        }
    }
    
    private func dateRangeText(for stay: Stay) -> String {
        let formatter = Date.FormatStyle(date: .abbreviated, time: .omitted)
        let start = stay.enteredOn.formatted(formatter)
        if let exit = stay.exitedOn {
            return "\(start) - \(exit.formatted(formatter))"
        }
        return "\(start) - Present"
    }
}

#Preview {
    PresenceDayDetailView(day: PresenceDay(
        dayKey: "2026-02-15",
        date: Date(),
        timeZoneId: TimeZone.current.identifier,
        countryCode: "ES",
        countryName: "Spain",
        confidence: 0.7,
        confidenceLabel: .medium,
        sources: [.photo, .location],
        isOverride: false,
        stayCount: 1,
        photoCount: 2,
        locationCount: 3
    ))
}

