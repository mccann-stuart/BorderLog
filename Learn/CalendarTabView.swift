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
        let symbols = calendar.shortStandaloneWeekdaySymbols.map { $0.uppercased() }
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
            VStack(alignment: .leading, spacing: 24) {
                monthToolbar
                monthCard
                summarySection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(CalendarTabBackground())
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.large)
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

    private var monthToolbar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(monthTitle)
                        .font(.system(.title2, design: .rounded).weight(.bold))

                    Text("Flags show unique countries found for each day. Flights add ✈️.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    MonthNavigationButton(
                        systemImage: "chevron.left",
                        isEnabled: canNavigateBackward,
                        action: { stepMonth(by: -1) }
                    )
                    MonthNavigationButton(
                        systemImage: "chevron.right",
                        isEnabled: canNavigateForward,
                        action: { stepMonth(by: 1) }
                    )
                }
            }

            if isLoading || loadError != nil {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }

                    Text(loadError ?? "Refreshing calendar…")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(loadError == nil ? Color.secondary : Color.red)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
            }
        }
    }

    private var monthCard: some View {
        VStack(spacing: 20) {
            weekdayHeader
            monthGrid
        }
        .padding(20)
        .calendarSurface()
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
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 14) {
            ForEach(Array(monthGridItems.enumerated()), id: \.offset) { item in
                if let daySummary = item.element {
                    dayCell(for: daySummary)
                } else {
                    Color.clear
                        .frame(minHeight: 86)
                }
            }
        }
        .gesture(monthSwipeGesture)
    }

    @ViewBuilder
    private func dayCell(for summary: CalendarDaySummary) -> some View {
        let cell = CalendarDayCell(
            summary: summary,
            isInteractive: presenceDaysByKey[summary.dayKey] != nil
        )

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

    private var summarySection: some View {
        let rows = countryRows

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Travel Summary")
                        .font(.system(.headline, design: .rounded).weight(.semibold))

                    Text("Each country counts once per day, even when multiple sources agree.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Menu {
                    Picker("Range", selection: $summaryRange) {
                        ForEach(CalendarCountrySummaryRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.subheadline.weight(.semibold))
                        Text(summaryRange.rawValue)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                }
            }

            if rows.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("No country days found")
                        .font(.system(.headline, design: .rounded))

                    Text("Change the month or summary range to see travel evidence.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(rows) { info in
                        CalendarCountrySummaryRow(info: info)
                    }
                }
            }
        }
        .padding(20)
        .calendarSurface()
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

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            visibleMonthStart = normalizedNextMonth
        }
    }

    private static func monthStart(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }
}

private struct CalendarTabBackground: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.72),
                    Color.blue.opacity(0.05),
                    Color(uiColor: .systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.accentColor.opacity(0.14),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 280
            )
            .offset(x: -80, y: -120)

            RadialGradient(
                colors: [
                    Color.white.opacity(0.55),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 240
            )
            .offset(x: 80, y: -40)
        }
        .ignoresSafeArea()
    }
}

private struct MonthNavigationButton: View {
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isEnabled ? .primary : .secondary)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }
}

private struct CalendarDayCell: View {
    let summary: CalendarDaySummary
    let isInteractive: Bool

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

    private var dayBubbleFill: Color {
        if summary.isToday {
            return .accentColor
        }
        if !emojiSummary.isEmpty {
            return Color(UIColor.secondarySystemGroupedBackground)
        }
        return Color(UIColor.tertiarySystemFill)
    }

    private var dayBubbleStroke: Color {
        if summary.isToday {
            return Color.accentColor.opacity(0.3)
        }
        if !emojiSummary.isEmpty {
            return Color.white.opacity(0.85)
        }
        return .clear
    }

    private var containerFill: Color {
        if summary.isToday {
            return Color.accentColor.opacity(0.12)
        }
        if !emojiSummary.isEmpty {
            return Color(UIColor.systemBackground).opacity(0.72)
        }
        return .clear
    }

    private var containerStroke: Color {
        if summary.isToday {
            return Color.accentColor.opacity(0.24)
        }
        if !emojiSummary.isEmpty {
            return Color.white.opacity(0.5)
        }
        return .clear
    }

    private var dayNumberColor: Color {
        summary.isToday ? .white : .primary
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(dayBubbleFill)

                Circle()
                    .stroke(dayBubbleStroke, lineWidth: summary.isToday ? 3 : 1)
                    .padding(summary.isToday ? -4 : 0)

                Text("\(summary.dayNumber)")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(dayNumberColor)
            }
            .frame(width: 42, height: 42)

            if !emojiSummary.isEmpty {
                Text(emojiSummary)
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity, minHeight: 18, alignment: .top)
            } else {
                Spacer(minLength: 18)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .top)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(containerFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(containerStroke, lineWidth: 1)
        }
        .opacity(isInteractive || !emojiSummary.isEmpty || summary.isToday ? 1 : 0.88)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct CalendarCountrySummaryRow: View {
    let info: CountryDaysInfo

    private var badgeTint: Color {
        if info.totalDays >= 90 {
            return .red
        } else if info.totalDays >= 80 {
            return .orange
        }
        return .primary
    }

    private var badgeBackground: Color {
        if info.totalDays >= 90 {
            return .red.opacity(0.12)
        } else if info.totalDays >= 80 {
            return .orange.opacity(0.12)
        }
        return Color(UIColor.secondarySystemGroupedBackground)
    }

    private var badgeTitle: String {
        "\(info.totalDays)d"
    }

    private var badgeSubtitle: String {
        if let maxAllowedDays = info.maxAllowedDays {
            return "of \(maxAllowedDays) allowed"
        }
        return "unique days"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.secondarySystemGroupedBackground))

                Text(info.flagEmoji)
                    .font(.system(size: 24))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(info.countryName)
                    .font(.system(.body, design: .rounded).weight(.semibold))

                Text(info.region.rawValue)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text(badgeTitle)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(badgeTint)

                Text(badgeSubtitle)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(badgeBackground, in: Capsule())
        }
        .padding(.horizontal, 2)
    }
}

private struct CalendarSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.65), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 24, y: 14)
    }
}

private extension View {
    func calendarSurface() -> some View {
        modifier(CalendarSurface())
    }
}

#Preview {
    NavigationStack {
        CalendarTabView()
            .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self, CountryConfig.self, CalendarSignal.self], inMemory: true)
    }
}
