//
//  CalendarEvidenceResolver.swift
//  Learn
//
//  Created by Codex on 20/03/2026.
//

import Foundation

struct CalendarEvidenceResolver {
    static func adjacentDayKeys(
        for dayKey: String,
        dayTimeZoneId: String?
    ) -> [String] {
        let timeZone = DayIdentity.canonicalTimeZone(preferredTimeZoneId: dayTimeZoneId)
        guard let date = DayKey.date(for: dayKey, timeZone: timeZone) else {
            return []
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let previous = calendar.date(byAdding: .day, value: -1, to: date)
        let next = calendar.date(byAdding: .day, value: 1, to: date)

        return [previous, next]
            .compactMap { $0 }
            .map { DayKey.make(from: $0, timeZone: timeZone) }
    }

    static func resolve(
        sameDaySignals: [CalendarSignal],
        adjacentSignals: [CalendarSignal],
        dayCountryCode: String?,
        dayCountryName: String?,
        calendarCount: Int,
        sources: SignalSourceMask
    ) -> [CalendarSignal] {
        guard sameDaySignals.isEmpty,
              calendarCount > 0,
              sources.contains(.calendar) else {
            return sortedDeduplicated(signals: sameDaySignals)
        }

        let limit = max(calendarCount, 1)
        let adjacentOriginSignals = adjacentSignals.filter { $0.source == "CalendarFlightOrigin" }
        let targetIdentity = countryIdentity(
            countryCode: dayCountryCode,
            countryName: dayCountryName
        )

        if let resolved = boundedSignals(
            signals: adjacentOriginSignals,
            targetIdentity: targetIdentity,
            limit: limit
        ) {
            return resolved
        }

        return boundedSignals(
            signals: adjacentSignals,
            targetIdentity: targetIdentity,
            limit: limit
        ) ?? []
    }

    private static func sortedDeduplicated(signals: [CalendarSignal]) -> [CalendarSignal] {
        var seen = Set<String>()
        let deduplicated = signals.filter { signal in
            seen.insert(signal.eventIdentifier).inserted
        }

        return deduplicated.sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.eventIdentifier < rhs.eventIdentifier
            }
            return lhs.timestamp < rhs.timestamp
        }
    }

    private static func countryIdentity(
        countryCode: String?,
        countryName: String?
    ) -> String? {
        if let code = CountryCodeNormalizer.canonicalCode(
            countryCode: countryCode,
            countryName: countryName
        ) {
            return code
        }

        guard let name = countryName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }

        return name.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        ).lowercased()
    }

    private static func boundedSignals(
        signals: [CalendarSignal],
        targetIdentity: String?,
        limit: Int
    ) -> [CalendarSignal]? {
        guard !signals.isEmpty else { return nil }

        let candidates: [CalendarSignal]
        if let targetIdentity {
            let matching = signals.filter { signal in
                countryIdentity(
                    countryCode: signal.countryCode,
                    countryName: signal.countryName
                ) == targetIdentity
            }
            guard !matching.isEmpty else { return nil }
            candidates = matching
        } else {
            candidates = signals
        }

        // ⚡ Bolt: Avoid O(N log N) sorting cost when we only need the top candidate.
        // We use .min(by:) which performs a single O(N) pass and O(1) memory, avoiding
        // the need for deduplication entirely since we only extract the absolute minimum.
        if limit == 1 {
            if let best = candidates.min(by: { lhs, rhs in
                if lhs.timestamp == rhs.timestamp {
                    return lhs.eventIdentifier < rhs.eventIdentifier
                }
                return lhs.timestamp < rhs.timestamp
            }) {
                return [best]
            }
            return []
        }

        return Array(sortedDeduplicated(signals: candidates).prefix(limit))
    }
}
