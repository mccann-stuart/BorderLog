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

    init() {
        let calendar = Calendar.current
        let monthStart = Self.monthStart(for: Date(), calendar: calendar)
        _visibleMonthStart = State(initialValue: monthStart)
        _snapshot = State(initialValue: CalendarTabSnapshot.placeholder(visibleMonthStart: monthStart, calendar: calendar))
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private var monthTitle: String {
        snapshot.visibleMonthStart.formatted(
            Date.FormatStyle()
                .month(.wide)
                .year()
        )
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let startIndex = max(calendar.firstWeekday - 1, 0)
        guard startIndex < symbols.count else { return symbols }
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private var canNavigateBackward: Bool {
        visibleMonthStart > snapshot.earliestAvailableMonth
    }

    private var canNavigateForward: Bool {
        visibleMonthStart < snapshot.latestAvailableMonth
    }

    private var monthGridItems: [CalendarDaySummary?] {
        guard let firstDay = snapshot.daySummaries.first?.date else { return [] }
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingBlankCount = (weekday - calendar.firstWeekday + 7) % 7

        var items = Array<CalendarDaySummary?>(repeating: nil, count: leadingBlankCount)
        items.append(contentsOf: snapshot.daySummaries)

        let trailingBlankCount = (7 - (items.count % 7)) % 7
        items.append(contentsOf: Array(repeating: nil, count: trailingBlankCount))
        return items
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
        ScrollView {
            VStack(spacing: 20) {
                monthSection
                tableSection
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
        .background {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                LinearGradient(colors: [.blue.opacity(0.05), .purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .ignoresSafeArea()
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
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
    }

    private var monthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Travel Calendar")
                    .font(.system(.title2, design: .rounded).bold())
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack {
                Button {
                    stepMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor.opacity(canNavigateBackward ? 0.14 : 0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canNavigateBackward)

                Spacer()

                Text(monthTitle)
                    .font(.system(.title3, design: .rounded).weight(.semibold))

                Spacer()

                Button {
                    stepMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor.opacity(canNavigateForward ? 0.14 : 0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canNavigateForward)
            }

            weekdayHeader
            monthGrid

            if let loadError {
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .cardShell()
    }

    private var weekdayHeader: some View {
        HStack(spacing: 8) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(Array(monthGridItems.enumerated()), id: \.offset) { item in
                if let daySummary = item.element {
                    dayCell(for: daySummary)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.clear)
                        .frame(minHeight: 84)
                }
            }
        }
        .gesture(monthSwipeGesture)
    }

    @ViewBuilder
    private func dayCell(for summary: CalendarDaySummary) -> some View {
        let cell = CalendarDayCell(summary: summary)
        if let presenceDay = presenceDaysByKey[summary.dayKey] {
            NavigationLink {
                PresenceDayDetailView(day: presenceDay)
            } label: {
                cell
            }
            .buttonStyle(.plain)
        } else {
            cell
        }
    }

    private var tableSection: some View {
        let rows = countryRows
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Country Days")
                    .font(.system(.title2, design: .rounded).bold())
                Spacer()
                Picker("Range", selection: $summaryRange) {
                    ForEach(CalendarCountrySummaryRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .tint(.secondary)
            }

            if rows.isEmpty {
                ContentUnavailableView(
                    "No country days",
                    systemImage: "globe",
                    description: Text("No countries were found in the selected calendar range.")
                )
                .frame(height: 200)
                .cardShell()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { info in
                        CountryDaysRow(info: info, warningThreshold: 80)
                            .padding(.horizontal)
                            .padding(.vertical, 8)

                        if info.id != rows.last?.id {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .cardShell()
            }
        }
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                guard abs(value.translation.width) > 60 else { return }

                if value.translation.width < 0 {
                    stepMonth(by: 1)
                } else {
                    stepMonth(by: -1)
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

    private func stepMonth(by value: Int) {
        guard value != 0 else { return }
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: visibleMonthStart) else { return }

        let normalizedNextMonth = Self.monthStart(for: nextMonth, calendar: calendar)
        if normalizedNextMonth < snapshot.earliestAvailableMonth || normalizedNextMonth > snapshot.latestAvailableMonth {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            visibleMonthStart = normalizedNextMonth
        }
    }

    private static func monthStart(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }
}

private struct CalendarDayCell: View {
    let summary: CalendarDaySummary

    private var emojiSummary: String {
        let flags = summary.countries.map { country in
            guard let code = country.countryCode else { return "🌍" }
            return countryCodeToEmoji(code)
        }
        var parts = flags
        if summary.hasFlight {
            parts.append("✈️")
        }
        return parts.joined(separator: " ")
    }

    private var backgroundFill: Color {
        if summary.isToday {
            return Color.accentColor.opacity(0.16)
        }
        if !summary.countries.isEmpty || summary.hasFlight {
            return Color.accentColor.opacity(0.08)
        }
        return Color(UIColor.secondarySystemGroupedBackground)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text("\(summary.dayNumber)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))

                Spacer(minLength: 6)

                if summary.isToday {
                    Text("Today")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.18))
                        .clipShape(Capsule())
                }
            }

            if !emojiSummary.isEmpty {
                Text(emojiSummary)
                    .font(.system(.caption2, design: .rounded))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(minHeight: 84, alignment: .topLeading)
        .background(backgroundFill)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(summary.isToday ? 0.5 : 0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        CalendarTabView()
            .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self, CountryConfig.self, CalendarSignal.self], inMemory: true)
    }
}
