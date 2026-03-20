//
//  CalendarTabView.swift
//  Learn
//
//  Created by Codex on 19/03/2026.
//

import SwiftUI
import SwiftData

struct CalendarTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var visibleMonthStart: Date
    @State private var summaryRange: CalendarCountrySummaryRange = .visibleMonth
    @State private var snapshot: CalendarTabSnapshot
    @State private var presenceDaysByKey: [String: PresenceDay] = [:]
    @State private var isLoading = false
    @State private var loadError: String?

    @State private var selectedDayKey: String? // for programmatic navigation

    init() {
        let calendar = Calendar.current
        let monthStart = Self.monthStart(for: Date(), calendar: calendar)
        _visibleMonthStart = State(initialValue: monthStart)
        _snapshot = State(initialValue: CalendarTabSnapshot.placeholder(visibleMonthStart: monthStart, calendar: calendar))
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private var countryRows: [CountryDaysInfo] {
        snapshot.countrySummaries.map { summary in
            CountryDaysInfo(
                countryName: summary.countryName,
                countryCode: summary.countryCode,
                totalDays: summary.totalDays,
                region: Region(rawValue: summary.regionRaw) ?? .other,
                maxAllowedDays: summary.maxAllowedDays
            )
        }
    }

    var body: some View {
        List {
            Section {
                NativeCalendarView(
                    visibleMonthStart: $visibleMonthStart,
                    snapshot: snapshot,
                    onDateSelected: { dayKey in
                        if presenceDaysByKey[dayKey] != nil {
                            selectedDayKey = dayKey
                        }
                    }
                )
                .frame(minHeight: 450)
                .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                .listRowBackground(Color.clear)
            }
            
            if let error = loadError {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section {
                Picker("Range", selection: $summaryRange) {
                    ForEach(CalendarCountrySummaryRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
            } header: {
                Text("Travel Summary")
            } footer: {
                Text("Each country counts once per day, even when multiple sources agree.")
            }

            Section {
                if countryRows.isEmpty {
                    Text("No country days found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(countryRows) { info in
                        CalendarCountrySummaryRow(info: info)
                    }
                }
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if isLoading {
                ToolbarItem(placement: .topBarTrailing) {
                    ProgressView()
                }
            }
        }
        .onAppear {
            Task { await refreshSnapshot() }
        }
        .onChange(of: visibleMonthStart) { _, _ in
            Task { await refreshSnapshot() }
        }
        .onChange(of: summaryRange) { _, _ in
            Task { await refreshSnapshot() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshSnapshot() }
        }
        .navigationDestination(item: $selectedDayKey) { dayKey in
            if let presenceDay = presenceDaysByKey[dayKey] {
                PresenceDayDetailView(day: presenceDay)
            }
        }
    }

    @MainActor
    private func refreshSnapshot() async {
        let requestedMonth = visibleMonthStart
        let requestedRange = summaryRange
        let service = CalendarTabDataService(modelContainer: modelContext.container)

        isLoading = true
        loadError = nil

        do {
            let loadedSnapshot = try await service.snapshot(
                visibleMonthStart: requestedMonth,
                summaryRange: requestedRange
            )
            guard requestedMonth == visibleMonthStart, requestedRange == summaryRange else { return }

            snapshot = loadedSnapshot
            loadPresenceDays(for: loadedSnapshot.daySummaries.map(\.dayKey))
        } catch {
            guard requestedMonth == visibleMonthStart, requestedRange == summaryRange else { return }
            loadError = error.localizedDescription
            loadPresenceDays(for: snapshot.daySummaries.map(\.dayKey))
        }

        if requestedMonth == visibleMonthStart, requestedRange == summaryRange {
            isLoading = false
        }
    }

    private func loadPresenceDays(for dayKeys: [String]) {
        guard !dayKeys.isEmpty else {
            presenceDaysByKey = [:]
            return
        }

        do {
            let descriptor = FetchDescriptor<PresenceDay>(
                predicate: #Predicate { day in
                    dayKeys.contains(day.dayKey)
                }
            )
            let days = try modelContext.fetch(descriptor)
            presenceDaysByKey = Dictionary(uniqueKeysWithValues: days.map { ($0.dayKey, $0) })
        } catch {
            presenceDaysByKey = [:]
        }
    }

    private static func monthStart(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }
}

// MARK: - Native Calendar Wrapper

struct NativeCalendarView: UIViewRepresentable {
    @Binding var visibleMonthStart: Date
    let snapshot: CalendarTabSnapshot
    let onDateSelected: (String) -> Void

    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = Calendar.current
        calendarView.locale = Locale.current
        calendarView.fontDesign = .rounded
        calendarView.delegate = context.coordinator
        
        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        calendarView.selectionBehavior = selection
        
        calendarView.visibleDateComponents = Calendar.current.dateComponents([.year, .month], from: visibleMonthStart)

        return calendarView
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        context.coordinator.snapshot = snapshot
        
        // Sync visible date if it changed upstream
        let targetMonthComponent = Calendar.current.dateComponents([.year, .month], from: visibleMonthStart)
        if uiView.visibleDateComponents.year != targetMonthComponent.year || 
           uiView.visibleDateComponents.month != targetMonthComponent.month {
            uiView.setVisibleDateComponents(targetMonthComponent, animated: true)
        }
        
        // Reload decorations for displayed month
        if let summaries = context.coordinator.snapshot?.daySummaries {
            let datesToReload = summaries.map { summary in
                Calendar.current.dateComponents([.year, .month, .day], from: summary.date)
            }
            uiView.reloadDecorations(forDateComponents: datesToReload, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, visibleMonthStart: $visibleMonthStart, onDateSelected: onDateSelected)
    }

    class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: NativeCalendarView
        var snapshot: CalendarTabSnapshot?
        var visibleMonthStart: Binding<Date>
        var onDateSelected: (String) -> Void

        init(_ parent: NativeCalendarView, visibleMonthStart: Binding<Date>, onDateSelected: @escaping (String) -> Void) {
            self.parent = parent
            self.visibleMonthStart = visibleMonthStart
            self.onDateSelected = onDateSelected
        }

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let date = Calendar.current.date(from: dateComponents) else { return nil }
            let dayKey = DayKey.make(from: date, timeZone: Calendar.current.timeZone)
            guard let summary = snapshot?.daySummaries.first(where: { $0.dayKey == dayKey }) else { return nil }
            
            let flags = summary.countries.map { country in
                guard let code = country.countryCode else { return "🌍" }
                return countryCodeToEmoji(code)
            }
            var emojis = flags
            if summary.hasFlight {
                emojis.append("✈️")
            }
            
            let emojiString = emojis.joined(separator: " ")
            if emojiString.isEmpty { return nil }
            
            return .customView {
                let label = UILabel()
                label.text = emojiString
                label.font = .systemFont(ofSize: 12)
                label.textAlignment = .center
                return label
            }
        }
        
        func calendarView(_ calendarView: UICalendarView, didChangeVisibleDateComponentsFrom previousDateComponents: DateComponents) {
            if let newDate = Calendar.current.date(from: calendarView.visibleDateComponents) {
                // To avoid SwiftUI state modification during view update, dispatch
                DispatchQueue.main.async {
                    self.visibleMonthStart.wrappedValue = Calendar.current.date(
                        from: Calendar.current.dateComponents([.year, .month], from: newDate)
                    ) ?? newDate
                }
            }
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents = dateComponents,
                  let date = Calendar.current.date(from: dateComponents) else { return }
            let dayKey = DayKey.make(from: date, timeZone: Calendar.current.timeZone)
            onDateSelected(dayKey)
            
            // clear selection to allow tapping again
            selection.setSelected(nil, animated: true)
        }
        
        func dateSelection(_ selection: UICalendarSelectionSingleDate, canSelectDate dateComponents: DateComponents?) -> Bool {
            return true
        }
    }
}

// MARK: - Subviews

private struct CalendarCountrySummaryRow: View {
    let info: CountryDaysInfo

    var body: some View {
        HStack(spacing: 12) {
            Text(info.flagEmoji)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text(info.countryName)
                    .font(.body)
                Text(info.region.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(info.totalDays)d")
                    .font(.headline)
                    .foregroundStyle(info.totalDays >= 90 ? .red : (info.totalDays >= 80 ? .orange : .primary))
                if let maxAllowedDays = info.maxAllowedDays {
                    Text("of \(maxAllowedDays) allowed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        CalendarTabView()
            .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self, CountryConfig.self, CalendarSignal.self], inMemory: true)
    }
}
