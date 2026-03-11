//
//  PresenceInferenceEngine.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation

struct PresenceInferenceEngine {
    private struct CountryKey: Hashable {
        let code: String?
        let name: String
    }

    private struct CountryAccumulator {
        var score: Double = 0
        var stayCount: Int = 0
        var photoCount: Int = 0
        var locationCount: Int = 0
        var calendarCount: Int = 0
    }

    private struct DayBucket {
        var countries: [CountryKey: CountryAccumulator] = [:]
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
            updateBucket(dayKey) { bucket in
                let key = CountryKey(code: countryCode, name: countryName)
                var accumulator = bucket.countries[key] ?? CountryAccumulator()
                accumulator.score += weight
                if stay { accumulator.stayCount += 1 }
                if photo { accumulator.photoCount += 1 }
                if location { accumulator.locationCount += 1 }
                if calendarSignal { accumulator.calendarCount += 1 }
                bucket.countries[key] = accumulator

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
                let overrideKey = CountryKey(code: overrideInfo.countryCode, name: overrideInfo.countryName)
                let accumulator = bucket.countries[overrideKey] ?? CountryAccumulator()
                var sources = SignalSourceMask.override
                if accumulator.stayCount > 0 { sources.formUnion(.stay) }
                if accumulator.photoCount > 0 { sources.formUnion(.photo) }
                if accumulator.locationCount > 0 { sources.formUnion(.location) }
                if accumulator.calendarCount > 0 { sources.formUnion(.calendar) }

                let result = PresenceDayResult(
                    dayKey: dayKey,
                    date: date,
                    timeZoneId: dayTimeZone.identifier,
                    countryCode: overrideInfo.countryCode,
                    countryName: overrideInfo.countryName,
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

            let sortedCountries = bucket.countries.sorted { $0.value.score > $1.value.score }
            guard let winner = sortedCountries.first else {
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

            let winnerScore = winner.value.score
            let totalScore = bucket.countries.values.reduce(0) { $0 + $1.score }
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
            if sortedCountries.count > 1 && sortedCountries[1].value.score > 0 {
                let scoreDelta = winner.value.score - sortedCountries[1].value.score
                let confidenceDelta = totalScore > 0 ? scoreDelta / totalScore : 0
                if confidenceDelta <= 0.5 {
                    isDisputed = true
                }
            }

            var sources = SignalSourceMask()
            if winner.value.stayCount > 0 { sources.formUnion(.stay) }
            if winner.value.photoCount > 0 { sources.formUnion(.photo) }
            if winner.value.locationCount > 0 { sources.formUnion(.location) }
            if winner.value.calendarCount > 0 { sources.formUnion(.calendar) }

            var suggestedCode1: String? = nil
            var suggestedName1: String? = nil
            var suggestedCode2: String? = nil
            var suggestedName2: String? = nil

            if isDisputed {
                suggestedCode1 = sortedCountries[0].key.code
                suggestedName1 = sortedCountries[0].key.name
                suggestedCode2 = sortedCountries[1].key.code
                suggestedName2 = sortedCountries[1].key.name
            }

            let result = PresenceDayResult(
                dayKey: dayKey,
                date: date,
                timeZoneId: dayTimeZone.identifier,
                countryCode: winner.key.code,
                countryName: winner.key.name,
                confidence: confidence,
                confidenceLabel: confidenceLabel,
                sources: sources,
                isOverride: false,
                isDisputed: isDisputed,
                stayCount: winner.value.stayCount,
                photoCount: winner.value.photoCount,
                locationCount: winner.value.locationCount,
                calendarCount: winner.value.calendarCount,
                suggestedCountryCode1: suggestedCode1,
                suggestedCountryName1: suggestedName1,
                suggestedCountryCode2: suggestedCode2,
                suggestedCountryName2: suggestedName2
            )
            appendResult(result)
        }

        var sortedResults = results.sorted { $0.date < $1.date }

        var i = 0
        while i < sortedResults.count {
            if sortedResults[i].countryCode == nil {
                var j = i
                while j < sortedResults.count, sortedResults[j].countryCode == nil {
                    j += 1
                }

                let gapLength = j - i

                if gapLength <= 7, i > 0, j < sortedResults.count {
                    let prev = sortedResults[i - 1]
                    let next = sortedResults[j]

                    if let prevCode = prev.countryCode,
                       let nextCode = next.countryCode,
                       prevCode == nextCode {
                        for k in i..<j {
                            let current = sortedResults[k]
                            sortedResults[k] = PresenceDayResult(
                                dayKey: current.dayKey,
                                date: current.date,
                                timeZoneId: current.timeZoneId ?? prev.timeZoneId,
                                countryCode: prevCode,
                                countryName: prev.countryName,
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

        // Optimization: Precalculate backward and forward suggestions in O(N) linear passes
        // to avoid O(N²) nested loops when filling gap days.
        var backwardSuggestions = [Optional<(code: String, name: String)>](repeating: nil, count: sortedResults.count)
        var currentBackward: (code: String, name: String)? = nil
        for i in 0..<sortedResults.count {
            backwardSuggestions[i] = currentBackward
            if let code = sortedResults[i].countryCode,
               let name = sortedResults[i].countryName {
                currentBackward = (code, name)
            }
        }

        var forwardSuggestions = [Optional<(code: String, name: String)>](repeating: nil, count: sortedResults.count)
        var currentForward: (code: String, name: String)? = nil
        for i in stride(from: sortedResults.count - 1, through: 0, by: -1) {
            forwardSuggestions[i] = currentForward
            if let code = sortedResults[i].countryCode,
               let name = sortedResults[i].countryName {
                currentForward = (code, name)
            }
        }

        for i in 0..<sortedResults.count {
            if sortedResults[i].countryCode == nil || sortedResults[i].confidence == 0 {
                var suggestions: [(code: String, name: String)] = []
                if let backwardSuggestion = backwardSuggestions[i] {
                    suggestions.append(backwardSuggestion)
                }
                if let forwardSuggestion = forwardSuggestions[i], forwardSuggestion.code != backwardSuggestions[i]?.code {
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
