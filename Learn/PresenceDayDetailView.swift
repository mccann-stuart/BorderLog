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
            Section("Actions") {
                Button("Override Day") {
                    isShowingOverride = true
                }
            }

            if day.countryCode == nil, let code1 = day.suggestedCountryCode1, let name1 = day.suggestedCountryName1 {
                Section("Suggestions") {
                    Button(action: {
                        applySuggestion(code: code1, name: name1)
                    }) {
                        HStack {
                            Text("Apply \(name1)")
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                    if let code2 = day.suggestedCountryCode2, let name2 = day.suggestedCountryName2, code2 != code1 {
                        Button(action: {
                            applySuggestion(code: code2, name: name2)
                        }) {
                            HStack {
                                Text("Apply \(name2)")
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                            }
                        }
                    }
                }
            }

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

    @Environment(\.modelContext) private var modelContext

    private func applySuggestion(code: String, name: String) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: day.date)
        let region: Region = {
            let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return .other }
            return SchengenMembers.isMember(trimmed) ? .schengen : .nonSchengen
        }()

        // Check if an override already exists for this day and update it in-place
        let predicate = #Predicate<DayOverride> { override in
            override.date == normalizedDate
        }
        let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate))
        if let existingOverride = existing?.first {
            existingOverride.countryName = name
            existingOverride.countryCode = code
            existingOverride.region = region
        } else {
            let newOverride = DayOverride(
                date: normalizedDate,
                countryName: name,
                countryCode: code,
                region: region
            )
            modelContext.insert(newOverride)
        }
        try? modelContext.save()
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
    
    var overlappingStays: [Stay] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) else { return [] }
        
        return stays.filter { stay in
            let stayStart = calendar.startOfDay(for: stay.enteredOn)
            let stayEnd = stay.exitedOn.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
            return startOfDay <= stayEnd && endOfDay >= stayStart
        }
    }
    
    var body: some View {
        let overlapping = overlappingStays

        Group {
            Section("Stays (\(overlapping.count))") {
                if overlapping.isEmpty {
                    Text("No matching stays")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(overlapping) { stay in
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
        do {
            var stayFetch = FetchDescriptor<Stay>()
            stayFetch.sortBy = [SortDescriptor(\.enteredOn, order: .reverse)]
            stays = try modelContext.fetch(stayFetch)
        } catch {
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
