//
//  PresenceInferenceEngine.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation

nonisolated struct PresenceInferenceEngine {
    private struct CountryKey: Hashable {
        let code: String?
        let name: String
    }

    private struct CountryAccumulator {
        var score: Double = 0
        var stayCount: Int = 0
        var photoCount: Int = 0
        var locationCount: Int = 0
    }

    private struct DayBucket {
        var countries: [CountryKey: CountryAccumulator] = [:]
        var timeZoneId: String?
    }

    static func compute(
        dayKeys: Set<String>,
        stays: [StayPresenceInfo],
        overrides: [OverridePresenceInfo],
        locations: [LocationSignalInfo],
        photos: [PhotoSignalInfo],
        rangeEnd: Date,
        calendar: Calendar = .current
    ) -> [PresenceDayResult] {
        let timeZone = calendar.timeZone
        var buckets: [String: DayBucket] = [:]

        func bucket(for dayKey: String) -> DayBucket {
            buckets[dayKey, default: DayBucket()]
        }

        func updateBucket(_ dayKey: String, _ update: (inout DayBucket) -> Void) {
            var current = bucket(for: dayKey)
            update(&current)
            buckets[dayKey] = current
        }

        func addScore(dayKey: String, countryCode: String?, countryName: String, weight: Double, stay: Bool, photo: Bool, location: Bool, timeZoneId: String?) {
            updateBucket(dayKey) { bucket in
                let key = CountryKey(code: countryCode, name: countryName)
                var accumulator = bucket.countries[key] ?? CountryAccumulator()
                accumulator.score += weight
                if stay { accumulator.stayCount += 1 }
                if photo { accumulator.photoCount += 1 }
                if location { accumulator.locationCount += 1 }
                bucket.countries[key] = accumulator
                if bucket.timeZoneId == nil {
                    bucket.timeZoneId = timeZoneId
                }
            }
        }

        // Manual stays
        for stay in stays {
            let start = calendar.startOfDay(for: stay.enteredOn)
            let rawEnd = calendar.startOfDay(for: stay.exitedOn ?? rangeEnd)
            let end = min(rawEnd, calendar.startOfDay(for: rangeEnd))
            guard start <= end else { continue }

            var day = start
            while day <= end {
                let dayKey = DayKey.make(from: day, timeZone: timeZone)
                if dayKeys.contains(dayKey) {
                    let countryName = stay.countryName
                    addScore(dayKey: dayKey, countryCode: stay.countryCode, countryName: countryName, weight: 5.0, stay: true, photo: false, location: false, timeZoneId: timeZone.identifier)
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        // Photo signals
        for photo in photos {
            if dayKeys.contains(photo.dayKey) {
                addScore(dayKey: photo.dayKey, countryCode: photo.countryCode, countryName: photo.countryName, weight: 2.0, stay: false, photo: true, location: false, timeZoneId: photo.timeZoneId)
            }
        }

        // Location samples
        for location in locations {
            if dayKeys.contains(location.dayKey) {
                let accuracy = max(location.accuracyMeters, 1)
                let accuracyFactor = min(1.0, max(0.2, 100.0 / accuracy))
                addScore(dayKey: location.dayKey, countryCode: location.countryCode, countryName: location.countryName, weight: 1.0 * accuracyFactor, stay: false, photo: false, location: true, timeZoneId: location.timeZoneId)
            }
        }

        // Overrides map
        var overrideMap: [String: OverridePresenceInfo] = [:]
        for overrideDay in overrides {
            let dayKey = DayKey.make(from: overrideDay.date, timeZone: timeZone)
            if dayKeys.contains(dayKey) {
                overrideMap[dayKey] = overrideDay
            }
        }

        var results: [PresenceDayResult] = []
        results.reserveCapacity(dayKeys.count)

        for dayKey in dayKeys {
            let bucket = buckets[dayKey] ?? DayBucket()
            let dayTimeZone = bucket.timeZoneId.flatMap { TimeZone(identifier: $0) } ?? timeZone
            let date = DayKey.date(for: dayKey, timeZone: dayTimeZone) ?? calendar.startOfDay(for: rangeEnd)

            if let overrideInfo = overrideMap[dayKey] {
                let overrideKey = CountryKey(code: overrideInfo.countryCode, name: overrideInfo.countryName)
                let accumulator = bucket.countries[overrideKey] ?? CountryAccumulator()
                var sources = SignalSourceMask.override
                if accumulator.stayCount > 0 { sources.formUnion(.stay) }
                if accumulator.photoCount > 0 { sources.formUnion(.photo) }
                if accumulator.locationCount > 0 { sources.formUnion(.location) }

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
                    stayCount: accumulator.stayCount,
                    photoCount: accumulator.photoCount,
                    locationCount: accumulator.locationCount
                )
                results.append(result)
                continue
            }

            guard let winner = bucket.countries.max(by: { $0.value.score < $1.value.score }) else {
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
                    stayCount: 0,
                    photoCount: 0,
                    locationCount: 0
                )
                results.append(result)
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
                    stayCount: 0,
                    photoCount: 0,
                    locationCount: 0
                )
                results.append(result)
                continue
            }

            var sources = SignalSourceMask()
            if winner.value.stayCount > 0 { sources.formUnion(.stay) }
            if winner.value.photoCount > 0 { sources.formUnion(.photo) }
            if winner.value.locationCount > 0 { sources.formUnion(.location) }

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
                stayCount: winner.value.stayCount,
                photoCount: winner.value.photoCount,
                locationCount: winner.value.locationCount
            )
            results.append(result)
        }

        var sortedResults = results.sorted { $0.date < $1.date }
        
        var i = 0
        while i < sortedResults.count {
            if sortedResults[i].countryCode == nil {
                // Find the extent of the gap
                var j = i
                while j < sortedResults.count, sortedResults[j].countryCode == nil {
                    j += 1
                }
                
                let gapLength = j - i
                
                // Check if gap is bounded by same country and length is <= 7
                if gapLength <= 7, i > 0, j < sortedResults.count {
                    let prev = sortedResults[i - 1]
                    let next = sortedResults[j]
                    
                    if let prevCode = prev.countryCode, let nextCode = next.countryCode, prevCode == nextCode {
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
                                stayCount: 0,
                                photoCount: 0,
                                locationCount: 0
                            )
                        }
                    }
                }
                
                i = j // Skip past the gap
            } else {
                i += 1
            }
        }

        return sortedResults
    }
}
