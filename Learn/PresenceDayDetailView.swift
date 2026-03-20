//
//  PresenceDayDetailView.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import SwiftUI
import SwiftData
import os

struct PresenceDayDetailView: View {
    private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "PresenceDayDetailView")

    let day: PresenceDay

    @State private var isShowingOverride = false
    @State private var isShowingAddStay = false
    @State private var appliedSuggestion: String? = nil
    @State private var isShowingDeleteAlert = false

    private var dayTimeZone: TimeZone {
        DayIdentity.canonicalTimeZone(preferredTimeZoneId: day.timeZoneId)
    }

    private var dayTitle: String {
        let localDate = DayIdentity.normalizedDate(
            for: day.dayKey,
            dayTimeZoneId: day.timeZoneId
        )
        var format = Date.FormatStyle(date: .long, time: .omitted)
        format.timeZone = dayTimeZone
        return "\(localDate.formatted(format)) (\(dayTimeZone.identifier))"
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

    private var localDate: Date {
        DayIdentity.normalizedDate(
            for: day.dayKey,
            dayTimeZoneId: day.timeZoneId
        )
    }

    var body: some View {
        Form {
            Section("Actions") {
                Button("Add Stay") {
                    isShowingAddStay = true
                }
                Button("Override Day") {
                    isShowingOverride = true
                }
                if day.isOverride {
                    Button("Delete Override", role: .destructive) {
                        isShowingDeleteAlert = true
                    }
                }
            }

            if (day.countryCode == nil || day.isDisputed), let code1 = day.suggestedCountryCode1, let name1 = day.suggestedCountryName1 {
                Section("Suggestions") {
                    Button(action: {
                        applySuggestion(code: code1, name: name1)
                        withAnimation(.easeInOut(duration: 0.35)) {
                            appliedSuggestion = code1
                        }
                    }) {
                        HStack {
                            if appliedSuggestion == code1 {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Applied")
                                    .foregroundStyle(.green)
                            } else {
                                Text("Apply \(name1)")
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                            }
                        }
                    }
                    .disabled(appliedSuggestion != nil)
                    if let code2 = day.suggestedCountryCode2, let name2 = day.suggestedCountryName2, code2 != code1 {
                        Button(action: {
                            applySuggestion(code: code2, name: name2)
                            withAnimation(.easeInOut(duration: 0.35)) {
                                appliedSuggestion = code2
                            }
                        }) {
                            HStack {
                                if appliedSuggestion == code2 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Applied")
                                        .foregroundStyle(.green)
                                } else {
                                    Text("Apply \(name2)")
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                }
                            }
                        }
                        .disabled(appliedSuggestion != nil)
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

                if day.isDisputed && !day.isManuallyModified {
                    HStack {
                        Text("Dispute")
                        Spacer()
                        Label("Conflicting evidence", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    Text("Signals conflict for this day. Review evidence and apply an override if needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if day.isOverride {
                    Text("This day has a manual override and will always win.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            EvidenceSection(day: day)
        }
        .navigationTitle("Day Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingOverride) {
            NavigationStack {
                DayOverrideEditorView(
                    overrideDay: nil,
                    presetDate: localDate,
                    presetCountryName: day.countryName,
                    presetCountryCode: day.countryCode
                )
            }
        }
        .sheet(isPresented: $isShowingAddStay) {
            NavigationStack {
                StayEditorView(
                    presetEntry: localDate,
                    presetCountryName: day.countryName,
                    presetCountryCode: day.countryCode,
                    forceExitDate: true
                )
            }
        }
        .alert("Delete Override", isPresented: $isShowingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteOverride()
            }
        } message: {
            Text("This will remove the manual override for this day. The day will revert to its inferred location.")
        }
    }

    @Environment(\.modelContext) private var modelContext

    private func applySuggestion(code: String, name: String) {
        let normalizedDate = localDate
        let normalizedCode = CountryCodeNormalizer.normalize(code) ?? code
        let dayKey = day.dayKey
        let region: Region = {
            let trimmed = normalizedCode.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return .other }
            return SchengenMembers.isMember(trimmed) ? .schengen : .nonSchengen
        }()

        // Check if an override already exists for this day and update it in-place
        let predicate = #Predicate<DayOverride> { override in
            override.dayKey == dayKey
        }
        let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate))
        if let existingOverride = existing?.first {
            existingOverride.date = normalizedDate
            existingOverride.dayKey = dayKey
            existingOverride.dayTimeZoneId = dayTimeZone.identifier
            existingOverride.countryName = name
            existingOverride.countryCode = normalizedCode
            existingOverride.region = region
        } else {
            let newOverride = DayOverride(
                date: normalizedDate,
                countryName: name,
                countryCode: normalizedCode,
                dayKey: dayKey,
                dayTimeZoneId: dayTimeZone.identifier,
                region: region
            )
            modelContext.insert(newOverride)
        }
        do {
            try modelContext.save()
            recomputeImpactedDay(dayKey)
        } catch {
            Self.logger.error("Failed to save override suggestion: \(error, privacy: .private)")
        }
    }

    private func deleteOverride() {
        let dayKey = day.dayKey
        let predicate = #Predicate<DayOverride> { override in
            override.dayKey == dayKey
        }
        if let matches = try? modelContext.fetch(FetchDescriptor(predicate: predicate)) {
            for match in matches {
                modelContext.delete(match)
            }
        }
        do {
            try modelContext.save()
            recomputeImpactedDay(dayKey)
        } catch {
            Self.logger.error("Failed to delete override: \(error, privacy: .private)")
        }
    }

    private func recomputeImpactedDay(_ dayKey: String) {
        let container = modelContext.container
        Task {
            // Need a slight delay to ensure SwiftData propagation to the background context
            try? await Task.sleep(nanoseconds: 150_000_000)
            let service = LedgerRecomputeService(modelContainer: container)
            await service.recompute(dayKeys: [dayKey])
        }
    }
}


private struct EvidenceSection: View {
    let day: PresenceDay
    
    @Environment(\.modelContext) private var modelContext

    @State private var locations: [LocationSample] = []
    @State private var photos: [PhotoSignal] = []
    @State private var overlappingStays: [Stay] = []
    @State private var calendarSignals: [CalendarSignal] = []
    
    private var dayTimeZone: TimeZone {
        DayIdentity.canonicalTimeZone(preferredTimeZoneId: day.timeZoneId)
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
                        NavigationLink {
                            StayEditorView(stay: stay)
                        } label: {
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
            }

            Section("Calendar Events (\(calendarSignals.count))") {
                if calendarSignals.isEmpty {
                    Text("No calendar evidence")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(calendarSignals) { signal in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(signal.countryName ?? signal.countryCode ?? "Unknown Location")
                                .font(.subheadline)
                            if let title = signal.title {
                                Text(title)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                            HStack {
                                Text(formattedEvidenceTime(signal.timestamp))
                                Spacer()
                                Text(String(format: "%.4f, %.4f", signal.latitude, signal.longitude))
                                    .font(.caption2)
                                    .monospacedDigit()
                            }
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
                                Text(formattedEvidenceTime(photo.timestamp))
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
                                Text(formattedEvidenceTime(loc.timestamp))
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
        .onChange(of: day.dayKey) { loadData() }
        .onChange(of: day.date) { loadData() }
        .onChange(of: day.timeZoneId) { loadData() }
        .onChange(of: day.countryCode) { loadData() }
        .onChange(of: day.countryName) { loadData() }
        .onChange(of: day.calendarCount) { loadData() }
        .onChange(of: day.sourcesRaw) { loadData() }
    }
    
    private func loadData() {
        let selectedDayKey = day.dayKey
        let selectedTimeZoneId = day.timeZoneId
        let selectedCountryCode = day.countryCode
        let selectedCountryName = day.countryName
        let selectedCalendarCount = day.calendarCount
        let selectedSources = day.sources

        // Locations for this dayKey, sorted by timestamp
        do {
            let locPredicate = #Predicate<LocationSample> { target in
                target.dayKey == selectedDayKey
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
                target.dayKey == selectedDayKey
            }
            var photoFetch = FetchDescriptor<PhotoSignal>(predicate: photoPredicate)
            photoFetch.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
            photos = try modelContext.fetch(photoFetch)
        } catch {
            photos = []
        }

        // Calendar signals for this dayKey, sorted by timestamp
        do {
            let sameDayPredicate = #Predicate<CalendarSignal> { target in
                target.dayKey == selectedDayKey
            }
            var sameDayFetch = FetchDescriptor<CalendarSignal>(predicate: sameDayPredicate)
            sameDayFetch.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
            let sameDaySignals = try modelContext.fetch(sameDayFetch)

            let adjacentSignals: [CalendarSignal]
            let adjacentDayKeys = CalendarEvidenceResolver.adjacentDayKeys(
                for: selectedDayKey,
                dayTimeZoneId: selectedTimeZoneId
            )
            if adjacentDayKeys.isEmpty {
                adjacentSignals = []
            } else {
                let adjacentPredicate = #Predicate<CalendarSignal> { target in
                    adjacentDayKeys.contains(target.dayKey)
                }
                var adjacentFetch = FetchDescriptor<CalendarSignal>(predicate: adjacentPredicate)
                adjacentFetch.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
                adjacentSignals = try modelContext.fetch(adjacentFetch)
            }

            calendarSignals = CalendarEvidenceResolver.resolve(
                sameDaySignals: sameDaySignals,
                adjacentSignals: adjacentSignals,
                dayCountryCode: selectedCountryCode,
                dayCountryName: selectedCountryName,
                calendarCount: selectedCalendarCount,
                sources: selectedSources
            )
        } catch {
            calendarSignals = []
        }

        // Stays sorted by enteredOn, reverse order
        do {
            let window = DayIdentity.dayWindow(
                dayKey: selectedDayKey,
                dayTimeZoneId: selectedTimeZoneId,
                fallback: dayTimeZone
            )
            let startOfDay = window.start
            let nextDayStart = window.end
            let distantFuture = Date.distantFuture

            let stayPredicate = #Predicate<Stay> { target in
                target.enteredOn < nextDayStart && (target.exitedOn ?? distantFuture) >= startOfDay
            }
            var stayFetch = FetchDescriptor<Stay>(predicate: stayPredicate)
            stayFetch.sortBy = [SortDescriptor(\.enteredOn, order: .reverse)]
            overlappingStays = try modelContext.fetch(stayFetch)
        } catch {
            overlappingStays = []
        }
    }
    
    private func dateRangeText(for stay: Stay) -> String {
        let formatter = Date.FormatStyle(date: .abbreviated, time: .omitted)
        var localFormatter = formatter
        localFormatter.timeZone = dayTimeZone
        let start = stay.enteredOn.formatted(localFormatter)
        if let exit = stay.exitedOn {
            return "\(start) - \(exit.formatted(localFormatter))"
        }
        return "\(start) - Present"
    }

    private func formattedEvidenceTime(_ date: Date) -> String {
        var formatter = Date.FormatStyle(date: .omitted, time: .shortened)
        formatter.timeZone = dayTimeZone
        return "\(date.formatted(formatter)) \(dayTimeZone.identifier)"
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
        locationCount: 3,
        calendarCount: 1
    ))
}
