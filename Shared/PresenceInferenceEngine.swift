//
//  PresenceInferenceEngine.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation

struct PresenceInferenceEngine {
    private struct ResolvedCountry: Hashable {
        let id: String
        let code: String?
        let name: String
    }

    private struct CountryAccumulator {
        var country: ResolvedCountry
        var score: Double = 0
        var stayCount: Int = 0
        var photoCount: Int = 0
        var locationCount: Int = 0
        var calendarCount: Int = 0
    }

    private struct DayBucket {
        var countries: [String: CountryAccumulator] = [:]
        var timeZoneScores: [String: Double] = [:]
    }

    static func compute(
        dayKeys: Set<String>,
        stays: [StayPresenceInfo],
        overrides: [OverridePresenceInfo],
        locations: [LocationSignalInfo],
        photos: [PhotoSignalInfo],
        calendarSignals: [CalendarSignalInfo],
        rangeEnd: Date,
        calendar: Calendar = .current,
        progress: ((Int, Int) -> Void)? = nil
    ) -> [PresenceDayResult] {
        let defaultTimeZone = calendar.timeZone
        var buckets: [String: DayBucket] = [:]
        let orderedDayKeys = dayKeys.sorted()
        let totalCount = orderedDayKeys.count
        let progressStride = 25

        func bucket(for dayKey: String) -> DayBucket {
            buckets[dayKey, default: DayBucket()]
        }

        func updateBucket(_ dayKey: String, _ update: (inout DayBucket) -> Void) {
            var current = bucket(for: dayKey)
            update(&current)
            buckets[dayKey] = current
        }

        func normalizedCountryIdentity(_ name: String) -> String {
            name.folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
        }

        func resolvedCountry(
            countryCode: String?,
            countryName: String?
        ) -> ResolvedCountry? {
            let canonicalCode = CountryCodeNormalizer.canonicalCode(
                countryCode: countryCode,
                countryName: countryName
            )
            let trimmedName = countryName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedName: String
            if let canonicalCode {
                resolvedName = trimmedName
                    ?? Locale.autoupdatingCurrent.localizedString(forRegionCode: canonicalCode)
                    ?? canonicalCode
            } else if let trimmedName, !trimmedName.isEmpty {
                resolvedName = trimmedName
            } else {
                return nil
            }

            let identity = canonicalCode ?? normalizedCountryIdentity(resolvedName)
            return ResolvedCountry(id: identity, code: canonicalCode, name: resolvedName)
        }

        func resolvedCountry(for result: PresenceDayResult) -> ResolvedCountry? {
            resolvedCountry(countryCode: result.countryCode, countryName: result.countryName)
        }

        func isKnownCountry(_ result: PresenceDayResult) -> Bool {
            resolvedCountry(for: result) != nil
        }

        func isOvernightOriginFlightSignal(_ signal: CalendarSignalInfo) -> Bool {
            if signal.source == "CalendarFlightOrigin" {
                return true
            }
            return signal.eventIdentifier?.hasSuffix("#origin") == true
        }

        func shouldPromoteDepartureDay(
            _ result: PresenceDayResult,
            to originCountry: ResolvedCountry
        ) -> Bool {
            guard let currentCountry = resolvedCountry(for: result) else {
                return true
            }

            return currentCountry.id == originCountry.id &&
                result.confidenceLabel == .low &&
                result.sources == .calendar &&
                result.stayCount == 0 &&
                result.photoCount == 0 &&
                result.locationCount == 0
        }

        func promotedCalendarAssumption(
            from result: PresenceDayResult,
            country: ResolvedCountry,
            timeZoneId: String?,
            calendarCount: Int
        ) -> PresenceDayResult {
            var sources = result.sources
            sources.formUnion(.calendar)

            return PresenceDayResult(
                dayKey: result.dayKey,
                date: result.date,
                timeZoneId: timeZoneId ?? result.timeZoneId,
                countryCode: country.code,
                countryName: country.name,
                confidence: max(result.confidence, 0.5),
                confidenceLabel: .medium,
                sources: sources,
                isOverride: false,
                isDisputed: false,
                stayCount: result.stayCount,
                photoCount: result.photoCount,
                locationCount: result.locationCount,
                calendarCount: max(result.calendarCount, calendarCount)
            )
        }

        func addScore(
            dayKey: String,
            countryCode: String?,
            countryName: String,
            weight: Double,
            stay: Bool,
            photo: Bool,
            location: Bool,
            calendarSignal: Bool,
            timeZoneId: String?
        ) {
            guard let country = resolvedCountry(
                countryCode: countryCode,
                countryName: countryName
            ) else {
                return
            }

            updateBucket(dayKey) { bucket in
                var accumulator = bucket.countries[country.id] ?? CountryAccumulator(country: country)
                if accumulator.country.code == nil, country.code != nil {
                    accumulator.country = country
                }
                accumulator.score += weight
                if stay { accumulator.stayCount += 1 }
                if photo { accumulator.photoCount += 1 }
                if location { accumulator.locationCount += 1 }
                if calendarSignal { accumulator.calendarCount += 1 }
                bucket.countries[country.id] = accumulator

                if let timeZoneId,
                   TimeZone(identifier: timeZoneId) != nil {
                    bucket.timeZoneScores[timeZoneId, default: 0] += weight
                }
            }
        }

        func selectedDayTimeZoneId(
            for bucket: DayBucket,
            preferredTimeZoneId: String?,
            fallback: String
        ) -> String {
            if let preferredTimeZoneId,
               TimeZone(identifier: preferredTimeZoneId) != nil {
                return preferredTimeZoneId
            }

            // ⚡ Bolt: Replace O(N log N) sort with O(N) max to avoid allocating a sorted array
            return bucket.timeZoneScores.max(by: { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key > rhs.key
                }
                return lhs.value < rhs.value
            })?.key ?? fallback
        }

        // Manual stays
        for stay in stays {
            let stayTimeZone = DayIdentity.canonicalTimeZone(
                preferredTimeZoneId: stay.dayTimeZoneId,
                fallback: defaultTimeZone
            )

            guard let start = DayKey.date(for: stay.entryDayKey, timeZone: stayTimeZone) else {
                continue
            }

            let rangeEndKey = DayKey.make(from: rangeEnd, timeZone: stayTimeZone)
            let clampedRangeEnd = DayKey.date(for: rangeEndKey, timeZone: stayTimeZone) ?? rangeEnd
            let exitKey = stay.exitDayKey ?? rangeEndKey
            let rawEnd = DayKey.date(for: exitKey, timeZone: stayTimeZone) ?? clampedRangeEnd
            let end = min(rawEnd, clampedRangeEnd)
            guard start <= end else { continue }

            var stayCalendar = Calendar(identifier: .gregorian)
            stayCalendar.timeZone = stayTimeZone

            var day = start
            while day <= end {
                let dayKey = DayKey.make(from: day, timeZone: stayTimeZone)
                if dayKeys.contains(dayKey) {
                    addScore(
                        dayKey: dayKey,
                        countryCode: stay.countryCode,
                        countryName: stay.countryName,
                        weight: 5.0,
                        stay: true,
                        photo: false,
                        location: false,
                        calendarSignal: false,
                        timeZoneId: stay.dayTimeZoneId
                    )
                }
                guard let next = stayCalendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        // Photo signals
        for photo in photos {
            if dayKeys.contains(photo.dayKey) {
                addScore(
                    dayKey: photo.dayKey,
                    countryCode: photo.countryCode,
                    countryName: photo.countryName,
                    weight: 2.0,
                    stay: false,
                    photo: true,
                    location: false,
                    calendarSignal: false,
                    timeZoneId: photo.timeZoneId
                )
            }
        }

        // Calendar signals
        for signal in calendarSignals {
            if dayKeys.contains(signal.dayKey) {
                addScore(
                    dayKey: signal.dayKey,
                    countryCode: signal.countryCode,
                    countryName: signal.countryName,
                    weight: 1.0,
                    stay: false,
                    photo: false,
                    location: false,
                    calendarSignal: true,
                    timeZoneId: signal.bucketingTimeZoneId ?? signal.timeZoneId
                )
            }
        }

        // Location samples
        for location in locations {
            if dayKeys.contains(location.dayKey) {
                let accuracy = max(location.accuracyMeters, 1)
                let accuracyFactor = min(1.0, max(0.2, 100.0 / accuracy))
                addScore(
                    dayKey: location.dayKey,
                    countryCode: location.countryCode,
                    countryName: location.countryName,
                    weight: 3.0 * accuracyFactor,
                    stay: false,
                    photo: false,
                    location: true,
                    calendarSignal: false,
                    timeZoneId: location.timeZoneId
                )
            }
        }

        var overrideMap: [String: OverridePresenceInfo] = [:]
        for overrideDay in overrides {
            guard dayKeys.contains(overrideDay.dayKey) else { continue }
            overrideMap[overrideDay.dayKey] = overrideDay
            updateBucket(overrideDay.dayKey) { bucket in
                bucket.timeZoneScores[overrideDay.dayTimeZoneId, default: 0] += 10
            }
        }

        var results: [PresenceDayResult] = []
        results.reserveCapacity(totalCount)
        var processedCount = 0

        func appendResult(_ result: PresenceDayResult) {
            results.append(result)
            processedCount += 1
            if processedCount % progressStride == 0 || processedCount == totalCount {
                progress?(processedCount, totalCount)
            }
        }

        for dayKey in orderedDayKeys {
            let bucket = buckets[dayKey] ?? DayBucket()
            let overrideInfo = overrideMap[dayKey]
            let selectedTimeZoneId = selectedDayTimeZoneId(
                for: bucket,
                preferredTimeZoneId: overrideInfo?.dayTimeZoneId,
                fallback: defaultTimeZone.identifier
            )
            let dayTimeZone = TimeZone(identifier: selectedTimeZoneId) ?? defaultTimeZone
            let date = DayKey.date(for: dayKey, timeZone: dayTimeZone) ?? calendar.startOfDay(for: rangeEnd)

            if let overrideInfo {
                guard let overrideCountry = resolvedCountry(
                    countryCode: overrideInfo.countryCode,
                    countryName: overrideInfo.countryName
                ) else {
                    continue
                }
                let accumulator = bucket.countries[overrideCountry.id] ?? CountryAccumulator(country: overrideCountry)
                var sources = SignalSourceMask.override
                if accumulator.stayCount > 0 { sources.formUnion(.stay) }
                if accumulator.photoCount > 0 { sources.formUnion(.photo) }
                if accumulator.locationCount > 0 { sources.formUnion(.location) }
                if accumulator.calendarCount > 0 { sources.formUnion(.calendar) }

                let result = PresenceDayResult(
                    dayKey: dayKey,
                    date: date,
                    timeZoneId: dayTimeZone.identifier,
                    countryCode: overrideCountry.code,
                    countryName: overrideCountry.name,
                    confidence: 1.0,
                    confidenceLabel: .high,
                    sources: sources,
                    isOverride: true,
                    isDisputed: false,
                    stayCount: accumulator.stayCount,
                    photoCount: accumulator.photoCount,
                    locationCount: accumulator.locationCount,
                    calendarCount: accumulator.calendarCount
                )
                appendResult(result)
                continue
            }

            // ⚡ Bolt: Single O(N) pass to find top two countries instead of full O(N log N) sort
            var winner: CountryAccumulator? = nil
            var runnerUp: CountryAccumulator? = nil
            var totalScore: Double = 0

            for accumulator in bucket.countries.values {
                totalScore += accumulator.score
                if winner == nil || accumulator.score > winner!.score {
                    runnerUp = winner
                    winner = accumulator
                } else if runnerUp == nil || accumulator.score > runnerUp!.score {
                    runnerUp = accumulator
                }
            }

            guard let winner = winner else {
                let result = PresenceDayResult(
                    dayKey: dayKey,
                    date: date,
                    timeZoneId: dayTimeZone.identifier,
                    countryCode: nil,
                    countryName: nil,
                    confidence: 0,
                    confidenceLabel: .low,
                    sources: .none,
                    isOverride: false,
                    isDisputed: false,
                    stayCount: 0,
                    photoCount: 0,
                    locationCount: 0,
                    calendarCount: 0
                )
                appendResult(result)
                continue
            }

            let winnerScore = winner.score
            let confidence = totalScore > 0 ? min(1.0, max(0.0, winnerScore / totalScore)) : 0

            let confidenceLabel: ConfidenceLabel
            if winnerScore >= 6 {
                confidenceLabel = .high
            } else if winnerScore >= 3 {
                confidenceLabel = .medium
            } else {
                confidenceLabel = .low
            }

            if winnerScore < 1.0 {
                let result = PresenceDayResult(
                    dayKey: dayKey,
                    date: date,
                    timeZoneId: dayTimeZone.identifier,
                    countryCode: nil,
                    countryName: nil,
                    confidence: confidence,
                    confidenceLabel: .low,
                    sources: .none,
                    isOverride: false,
                    isDisputed: false,
                    stayCount: 0,
                    photoCount: 0,
                    locationCount: 0,
                    calendarCount: 0
                )
                appendResult(result)
                continue
            }

            var isDisputed = false
            if let runnerUp = runnerUp, runnerUp.score > 0 {
                let scoreDelta = winner.score - runnerUp.score
                let confidenceDelta = totalScore > 0 ? scoreDelta / totalScore : 0
                if confidenceDelta <= 0.5 {
                    isDisputed = true
                }
            }

            var sources = SignalSourceMask()
            if winner.stayCount > 0 { sources.formUnion(.stay) }
            if winner.photoCount > 0 { sources.formUnion(.photo) }
            if winner.locationCount > 0 { sources.formUnion(.location) }
            if winner.calendarCount > 0 { sources.formUnion(.calendar) }

            var suggestedCode1: String? = nil
            var suggestedName1: String? = nil
            var suggestedCode2: String? = nil
            var suggestedName2: String? = nil

            if isDisputed {
                suggestedCode1 = winner.country.code
                suggestedName1 = winner.country.name
                suggestedCode2 = runnerUp?.country.code
                suggestedName2 = runnerUp?.country.name
            }

            let result = PresenceDayResult(
                dayKey: dayKey,
                date: date,
                timeZoneId: dayTimeZone.identifier,
                countryCode: winner.country.code,
                countryName: winner.country.name,
                confidence: confidence,
                confidenceLabel: confidenceLabel,
                sources: sources,
                isOverride: false,
                isDisputed: isDisputed,
                stayCount: winner.stayCount,
                photoCount: winner.photoCount,
                locationCount: winner.locationCount,
                calendarCount: winner.calendarCount,
                suggestedCountryCode1: suggestedCode1,
                suggestedCountryName1: suggestedName1,
                suggestedCountryCode2: suggestedCode2,
                suggestedCountryName2: suggestedName2
            )
            appendResult(result)
        }

        var sortedResults = results.sorted { $0.date < $1.date }
        var overnightOriginFlightsByDayKey: [String: (country: ResolvedCountry, count: Int)] = [:]

        do {
            var groupedOriginFlights: [String: [String: (country: ResolvedCountry, count: Int)]] = [:]
            for signal in calendarSignals where isOvernightOriginFlightSignal(signal) {
                guard let country = resolvedCountry(
                    countryCode: signal.countryCode,
                    countryName: signal.countryName
                ) else {
                    continue
                }

                var dayFlights = groupedOriginFlights[signal.dayKey] ?? [:]
                var entry = dayFlights[country.id] ?? (country: country, count: 0)
                entry.count += 1
                dayFlights[country.id] = entry
                groupedOriginFlights[signal.dayKey] = dayFlights
            }

            for (dayKey, dayFlights) in groupedOriginFlights {
                let rankedFlights = dayFlights.values.sorted { lhs, rhs in
                    if lhs.count == rhs.count {
                        return lhs.country.id < rhs.country.id
                    }
                    return lhs.count > rhs.count
                }
                guard let winner = rankedFlights.first else { continue }
                if rankedFlights.count > 1,
                   rankedFlights[1].count == winner.count,
                   rankedFlights[1].country.id != winner.country.id {
                    continue
                }
                overnightOriginFlightsByDayKey[dayKey] = winner
            }
        }

        var i = 0
        while i < sortedResults.count {
            if !isKnownCountry(sortedResults[i]) {
                var j = i
                while j < sortedResults.count, !isKnownCountry(sortedResults[j]) {
                    j += 1
                }

                let gapLength = j - i

                if gapLength <= 7, i > 0, j < sortedResults.count {
                    let prev = sortedResults[i - 1]
                    let next = sortedResults[j]

                    if let prevCountry = resolvedCountry(for: prev),
                       let nextCountry = resolvedCountry(for: next),
                       prevCountry.id == nextCountry.id {
                        for k in i..<j {
                            let current = sortedResults[k]
                            sortedResults[k] = PresenceDayResult(
                                dayKey: current.dayKey,
                                date: current.date,
                                timeZoneId: current.timeZoneId ?? prev.timeZoneId,
                                countryCode: prevCountry.code,
                                countryName: prevCountry.name,
                                confidence: 0.5,
                                confidenceLabel: .medium,
                                sources: .none,
                                isOverride: false,
                                isDisputed: false,
                                stayCount: 0,
                                photoCount: 0,
                                locationCount: 0,
                                calendarCount: 0
                            )
                        }
                    }
                }

                i = j
            } else {
                i += 1
            }
        }

        if !overnightOriginFlightsByDayKey.isEmpty {
            for index in 0..<sortedResults.count {
                let current = sortedResults[index]
                guard let originFlight = overnightOriginFlightsByDayKey[current.dayKey] else {
                    continue
                }

                if shouldPromoteDepartureDay(current, to: originFlight.country) {
                    sortedResults[index] = promotedCalendarAssumption(
                        from: current,
                        country: originFlight.country,
                        timeZoneId: current.timeZoneId,
                        calendarCount: originFlight.count
                    )
                }

                guard index > 0 else { continue }
                let previous = sortedResults[index - 1]
                guard !isKnownCountry(previous) else { continue }

                sortedResults[index - 1] = promotedCalendarAssumption(
                    from: previous,
                    country: originFlight.country,
                    timeZoneId: current.timeZoneId ?? previous.timeZoneId,
                    calendarCount: originFlight.count
                )
            }
        }

        // Optimization: Precalculate backward and forward suggestions in O(N) linear passes
        // to avoid O(N²) nested loops when filling gap days.
        var backwardSuggestions = [ResolvedCountry?](repeating: nil, count: sortedResults.count)
        var currentBackward: ResolvedCountry? = nil
        for i in 0..<sortedResults.count {
            backwardSuggestions[i] = currentBackward
            if let country = resolvedCountry(for: sortedResults[i]) {
                currentBackward = country
            }
        }

        var forwardSuggestions = [ResolvedCountry?](repeating: nil, count: sortedResults.count)
        var currentForward: ResolvedCountry? = nil
        for i in stride(from: sortedResults.count - 1, through: 0, by: -1) {
            forwardSuggestions[i] = currentForward
            if let country = resolvedCountry(for: sortedResults[i]) {
                currentForward = country
            }
        }

        for i in 0..<sortedResults.count {
            if !isKnownCountry(sortedResults[i]) || sortedResults[i].confidence == 0 {
                var suggestions: [ResolvedCountry] = []
                if let backwardSuggestion = backwardSuggestions[i] {
                    suggestions.append(backwardSuggestion)
                }
                if let forwardSuggestion = forwardSuggestions[i], forwardSuggestion.id != backwardSuggestions[i]?.id {
                    suggestions.append(forwardSuggestion)
                }

                if !suggestions.isEmpty {
                    var updated = sortedResults[i]
                    updated.suggestedCountryCode1 = suggestions[0].code
                    updated.suggestedCountryName1 = suggestions[0].name
                    if suggestions.count > 1 {
                        updated.suggestedCountryCode2 = suggestions[1].code
                        updated.suggestedCountryName2 = suggestions[1].name
                    }
                    sortedResults[i] = updated
                }
            }
        }

        return sortedResults
    }
}
