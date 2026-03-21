//
//  PresenceInferenceEngine.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation

struct ResolvedCountry: Hashable {
    let id: String
    let code: String?
    let name: String
}

struct InferenceContext {
    let dayKeys: Set<String>
    let stays: [StayPresenceInfo]
    let overrides: [OverridePresenceInfo]
    let locations: [LocationSignalInfo]
    let photos: [PhotoSignalInfo]
    let calendarSignals: [CalendarSignalInfo]
    let rangeEnd: Date
    let calendar: Calendar
    let progress: ((Int, Int) -> Void)?
}

struct DayBucket {
    var countryScores: [String: Double] = [:]
    var countries: [String: ResolvedCountry] = [:]
    var stayCount: Int = 0
    var photoCount: Int = 0
    var locationCount: Int = 0
    var calendarCount: Int = 0
    var evidence: [SignalImpact] = []
    var timeZoneScores: [String: Double] = [:]
    var overrideInfo: OverridePresenceInfo? = nil
    
    // For origin flight promotions
    var flightOriginCandidates: [String: (country: ResolvedCountry, count: Int, timeZoneId: String?)] = [:]
    
    var totalScore: Double {
        countryScores.values.reduce(0, +)
    }
}

protocol InferenceMiddleware {
    func process(buckets: inout [String: DayBucket], context: InferenceContext)
}

struct PresenceInferencePipeline {
    let middlewares: [InferenceMiddleware]
    
    func execute(context: InferenceContext) -> [PresenceDayResult] {
        var buckets: [String: DayBucket] = [:]
        for dayKey in context.dayKeys {
            buckets[dayKey] = DayBucket()
        }
        
        for middleware in middlewares {
            middleware.process(buckets: &buckets, context: context)
        }
        
        let compiler = ResultCompiler(context: context)
        return compiler.compile(buckets: buckets)
    }
}

// MARK: - Utilities

fileprivate func normalizedCountryIdentity(_ name: String) -> String {
    name.folding(
        options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
    )
    .lowercased()
}

fileprivate func resolveCountry(countryCode: String?, countryName: String?) -> ResolvedCountry? {
    let canonicalCode = CountryCodeNormalizer.canonicalCode(countryCode: countryCode, countryName: countryName)
    let trimmedName = countryName?.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedName: String
    if let canonicalCode {
        resolvedName = trimmedName ?? Locale.autoupdatingCurrent.localizedString(forRegionCode: canonicalCode) ?? canonicalCode
    } else if let trimmedName, !trimmedName.isEmpty {
        resolvedName = trimmedName
    } else {
        return nil
    }
    let identity = canonicalCode ?? normalizedCountryIdentity(resolvedName)
    return ResolvedCountry(id: identity, code: canonicalCode, name: resolvedName)
}

fileprivate func addScore(
    to bucket: inout DayBucket,
    countryCode: String?,
    countryName: String,
    weight: Double,
    source: String,
    timeZoneId: String?
) {
    guard let country = resolveCountry(countryCode: countryCode, countryName: countryName) else { return }
    let priorScore = bucket.countryScores[country.id] ?? 0
    bucket.countryScores[country.id] = priorScore + weight
    
    if bucket.countries[country.id]?.code == nil && country.code != nil {
        bucket.countries[country.id] = country
    } else if bucket.countries[country.id] == nil {
        bucket.countries[country.id] = country
    }
    
    bucket.evidence.append(SignalImpact(
        source: source,
        countryCode: country.code,
        countryName: country.name,
        scoreDelta: weight
    ))
    
    if let timeZoneId, TimeZone(identifier: timeZoneId) != nil {
        bucket.timeZoneScores[timeZoneId, default: 0] += weight
    }
    
    switch source {
    case "stay": bucket.stayCount += 1
    case "photo": bucket.photoCount += 1
    case "location": bucket.locationCount += 1
    case "calendar": bucket.calendarCount += 1
    default: break
    }
}

// MARK: - Middlewares

struct StayMiddleware: InferenceMiddleware {
    func process(buckets: inout [String: DayBucket], context: InferenceContext) {
        let defaultTimeZone = context.calendar.timeZone
        for stay in context.stays {
            let stayTimeZone = DayIdentity.canonicalTimeZone(preferredTimeZoneId: stay.dayTimeZoneId, fallback: defaultTimeZone)
            guard let start = DayKey.date(for: stay.entryDayKey, timeZone: stayTimeZone) else { continue }
            
            let rangeEndKey = DayKey.make(from: context.rangeEnd, timeZone: stayTimeZone)
            let clampedRangeEnd = DayKey.date(for: rangeEndKey, timeZone: stayTimeZone) ?? context.rangeEnd
            let exitKey = stay.exitDayKey ?? rangeEndKey
            let rawEnd = DayKey.date(for: exitKey, timeZone: stayTimeZone) ?? clampedRangeEnd
            let end = min(rawEnd, clampedRangeEnd)
            guard start <= end else { continue }
            
            var stayCalendar = Calendar(identifier: .gregorian)
            stayCalendar.timeZone = stayTimeZone
            
            var day = start
            while day <= end {
                let dayKey = DayKey.make(from: day, timeZone: stayTimeZone)
                if context.dayKeys.contains(dayKey) {
                    var bucket = buckets[dayKey] ?? DayBucket()
                    addScore(to: &bucket, countryCode: stay.countryCode, countryName: stay.countryName, weight: 5.0, source: "stay", timeZoneId: stay.dayTimeZoneId)
                    buckets[dayKey] = bucket
                }
                guard let next = stayCalendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
    }
}

struct PhotoMiddleware: InferenceMiddleware {
    func process(buckets: inout [String: DayBucket], context: InferenceContext) {
        for photo in context.photos {
            if context.dayKeys.contains(photo.dayKey) {
                var bucket = buckets[photo.dayKey] ?? DayBucket()
                addScore(to: &bucket, countryCode: photo.countryCode, countryName: photo.countryName, weight: 2.0, source: "photo", timeZoneId: photo.timeZoneId)
                buckets[photo.dayKey] = bucket
            }
        }
    }
}

struct LocationMiddleware: InferenceMiddleware {
    func process(buckets: inout [String: DayBucket], context: InferenceContext) {
        for location in context.locations {
            if context.dayKeys.contains(location.dayKey) {
                var bucket = buckets[location.dayKey] ?? DayBucket()
                let accuracy = max(location.accuracyMeters, 1)
                // Dynamic Calibration Component: Smooth decay from high accuracy +3.0 to low accuracy +0.6
                let accuracyFactor = min(1.0, max(0.2, 100.0 / accuracy))
                addScore(to: &bucket, countryCode: location.countryCode, countryName: location.countryName, weight: 3.0 * accuracyFactor, source: "location", timeZoneId: location.timeZoneId)
                buckets[location.dayKey] = bucket
            }
        }
    }
}

struct CalendarMiddleware: InferenceMiddleware {
    private func isOriginFlightSignal(_ signal: CalendarSignalInfo) -> Bool {
        if signal.source == "CalendarFlightOrigin" { return true }
        return signal.eventIdentifier?.hasSuffix("#origin") == true
    }
    
    func process(buckets: inout [String: DayBucket], context: InferenceContext) {
        for signal in context.calendarSignals {
            var bucket = buckets[signal.dayKey] ?? DayBucket()
            if isOriginFlightSignal(signal) {
                // Store origin flights for contextual promotion later
                if let country = resolveCountry(countryCode: signal.countryCode, countryName: signal.countryName) {
                    var entry = bucket.flightOriginCandidates[country.id] ?? (country, 0, signal.bucketingTimeZoneId ?? signal.timeZoneId)
                    entry.count += 1
                    bucket.flightOriginCandidates[country.id] = entry
                }
            } else {
                if context.dayKeys.contains(signal.dayKey) {
                    addScore(to: &bucket, countryCode: signal.countryCode, countryName: signal.countryName, weight: 1.0, source: "calendar", timeZoneId: signal.bucketingTimeZoneId ?? signal.timeZoneId)
                }
            }
            buckets[signal.dayKey] = bucket
        }
    }
}

struct OverrideMiddleware: InferenceMiddleware {
    func process(buckets: inout [String: DayBucket], context: InferenceContext) {
        for overrideDay in context.overrides {
            guard context.dayKeys.contains(overrideDay.dayKey) else { continue }
            var bucket = buckets[overrideDay.dayKey] ?? DayBucket()
            bucket.overrideInfo = overrideDay
            bucket.timeZoneScores[overrideDay.dayTimeZoneId, default: 0] += 10
            buckets[overrideDay.dayKey] = bucket
        }
    }
}

// MARK: - Compiler

struct ResultCompiler {
    let context: InferenceContext

    private struct TravelEventEndpoint {
        let dayKey: String
        let country: ResolvedCountry
        let timeZoneId: String?
    }

    private struct TravelEventContext {
        let baseEventIdentifier: String
        let origin: TravelEventEndpoint
        let destination: TravelEventEndpoint
    }
    
    private func selectedDayTimeZoneId(for bucket: DayBucket, preferredTimeZoneId: String?, fallback: String) -> String {
        if let preferredTimeZoneId, TimeZone(identifier: preferredTimeZoneId) != nil {
            return preferredTimeZoneId
        }
        return bucket.timeZoneScores.max(by: { lhs, rhs in
            lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
        })?.key ?? fallback
    }

    func compile(buckets: [String: DayBucket]) -> [PresenceDayResult] {
        let defaultTimeZone = context.calendar.timeZone
        var results: [PresenceDayResult] = []
        let orderedDayKeys = context.dayKeys.sorted()
        results.reserveCapacity(orderedDayKeys.count)
        
        // 1. Base Score Resolution and Transit Day Modeling
        for (index, dayKey) in orderedDayKeys.enumerated() {
            let bucket = buckets[dayKey] ?? DayBucket()
            let selectedTimeZoneId = selectedDayTimeZoneId(for: bucket, preferredTimeZoneId: bucket.overrideInfo?.dayTimeZoneId, fallback: defaultTimeZone.identifier)
            let dayTimeZone = TimeZone(identifier: selectedTimeZoneId) ?? defaultTimeZone
            let date = DayKey.date(for: dayKey, timeZone: dayTimeZone) ?? context.calendar.startOfDay(for: context.rangeEnd)
            
            if let indexProgress = context.progress {
                indexProgress(index + 1, orderedDayKeys.count)
            }
            
            if let overrideInfo = bucket.overrideInfo,
               let overrideCountry = resolveCountry(countryCode: overrideInfo.countryCode, countryName: overrideInfo.countryName) {
                
                var sources = SignalSourceMask.override
                if bucket.stayCount > 0 { sources.formUnion(.stay) }
                if bucket.photoCount > 0 { sources.formUnion(.photo) }
                if bucket.locationCount > 0 { sources.formUnion(.location) }
                if bucket.calendarCount > 0 { sources.formUnion(.calendar) }
                
                let contributed = ContributedCountry(countryCode: overrideCountry.code, countryName: overrideCountry.name, probability: 1.0)
                
                var overrideEvidence = bucket.evidence
                overrideEvidence.append(SignalImpact(source: "override", countryCode: overrideCountry.code, countryName: overrideCountry.name, scoreDelta: 1000.0))
                
                results.append(PresenceDayResult(
                    dayKey: dayKey,
                    date: date,
                    timeZoneId: dayTimeZone.identifier,
                    contributedCountries: [contributed],
                    zoneOverlays: [],
                    evidence: overrideEvidence,
                    confidence: 1.0,
                    confidenceLabel: .high,
                    sources: sources,
                    isOverride: true,
                    isDisputed: false,
                    stayCount: bucket.stayCount,
                    photoCount: bucket.photoCount,
                    locationCount: bucket.locationCount,
                    calendarCount: bucket.calendarCount
                ))
                continue
            }
            
            var totalScore: Double = 0
            let rankedCountries = bucket.countryScores.compactMap { key, score -> (ResolvedCountry, Double)? in
                guard let c = bucket.countries[key] else { return nil }
                totalScore += score
                return (c, score)
            }.sorted { $0.1 > $1.1 }
            
            if rankedCountries.isEmpty || rankedCountries[0].1 < 1.0 {
                results.append(PresenceDayResult(
                    dayKey: dayKey,
                    date: date,
                    timeZoneId: dayTimeZone.identifier,
                    contributedCountries: [],
                    zoneOverlays: [],
                    evidence: bucket.evidence,
                    confidence: 0,
                    confidenceLabel: .low,
                    sources: .none,
                    isOverride: false,
                    isDisputed: false,
                    stayCount: 0,
                    photoCount: 0,
                    locationCount: 0, calendarCount: 0
                ))
                continue
            }
            
            let winner = rankedCountries[0]
            var isDisputed = false
            if rankedCountries.count > 1 {
                let runnerUp = rankedCountries[1]
                let confidenceDelta = (winner.1 - runnerUp.1) / totalScore
                if confidenceDelta <= 0.5 { isDisputed = true }
            }
            
            // Nuanced Transit Days: instead of just a single winner, map to ContributedCountry array for top 2
            let contributedCountries = rankedCountries.prefix(2).map { c, score in
                ContributedCountry(countryCode: c.code, countryName: c.name, probability: score / totalScore)
            }
            
            let confidence = min(1.0, max(0.0, winner.1 / totalScore))
            let confidenceLabel: ConfidenceLabel = winner.1 >= 6 ? .high : (winner.1 >= 3 ? .medium : .low)
            
            var sources = SignalSourceMask()
            if bucket.stayCount > 0 { sources.formUnion(.stay) }
            if bucket.photoCount > 0 { sources.formUnion(.photo) }
            if bucket.locationCount > 0 { sources.formUnion(.location) }
            if bucket.calendarCount > 0 { sources.formUnion(.calendar) }
            
            var result = PresenceDayResult(
                dayKey: dayKey,
                date: date,
                timeZoneId: dayTimeZone.identifier,
                contributedCountries: contributedCountries,
                zoneOverlays: [],
                evidence: bucket.evidence,
                confidence: confidence,
                confidenceLabel: confidenceLabel,
                sources: sources,
                isOverride: false,
                isDisputed: isDisputed,
                stayCount: bucket.stayCount,
                photoCount: bucket.photoCount,
                locationCount: bucket.locationCount, calendarCount: bucket.calendarCount
            )
            
            if isDisputed {
                result.suggestedCountryCode1 = rankedCountries[0].0.code
                result.suggestedCountryName1 = rankedCountries[0].0.name
                if rankedCountries.count > 1 {
                    result.suggestedCountryCode2 = rankedCountries[1].0.code
                    result.suggestedCountryName2 = rankedCountries[1].0.name
                }
            }
            
            results.append(result)
        }
        
        var sortedResults = results.sorted { $0.date < $1.date }
        let travelEvents = buildTravelEventContexts()
        
        // 2. Contextual Influence and Gap Bridging (Day-before / Day-after Smoothing)
        var i = 0
        while i < sortedResults.count {
            if sortedResults[i].contributedCountries.isEmpty {
                var j = i
                while j < sortedResults.count, sortedResults[j].contributedCountries.isEmpty {
                    j += 1
                }
                
                let gapLength = j - i
                if gapLength <= 7, i > 0, j < sortedResults.count {
                    let prevCountries = sortedResults[i - 1].contributedCountries
                    let nextCountries = sortedResults[j].contributedCountries
                    
                    if let prevPrimary = prevCountries.first,
                       let nextPrimary = nextCountries.first,
                       prevPrimary.countryCode == nextPrimary.countryCode || prevPrimary.countryName.lowercased() == nextPrimary.countryName.lowercased() {
                        
                        let bridgedCountry = ContributedCountry(countryCode: prevPrimary.countryCode, countryName: prevPrimary.countryName, probability: 1.0)
                        
                        for k in i..<j {
                            var bridgingEvidence = sortedResults[k].evidence
                            bridgingContextualSmoothing(from: prevPrimary, to: nextPrimary, evidence: &bridgingEvidence)
                            
                            sortedResults[k] = PresenceDayResult(
                                dayKey: sortedResults[k].dayKey,
                                date: sortedResults[k].date,
                                timeZoneId: sortedResults[k].timeZoneId ?? sortedResults[i - 1].timeZoneId,
                                contributedCountries: [bridgedCountry],
                                zoneOverlays: [],
                                evidence: bridgingEvidence,
                                confidence: 0.5,
                                confidenceLabel: .medium,
                                sources: .none,
                                isOverride: false, isDisputed: false,
                                stayCount: 0, photoCount: 0, locationCount: 0, calendarCount: 0
                            )
                        }
                    }
                }
                i = j
            } else {
                i += 1
            }
        }
        
        // 3. Travel-backed adjacent day promotions
        applyAdjacentTravelPromotions(results: &sortedResults, travelEvents: travelEvents)

        // 4. Origin-flight promotion (Contextual Promotion)
        for index in 0..<sortedResults.count {
            let currentDayKey = sortedResults[index].dayKey
            guard let bucket = buckets[currentDayKey] else { continue }
            
            let rankedFlights = bucket.flightOriginCandidates.values.sorted { lhs, rhs in
                lhs.count == rhs.count ? lhs.country.id < rhs.country.id : lhs.count > rhs.count
            }
            
            guard let winnerFlight = rankedFlights.first else { continue }
            if rankedFlights.count > 1 && rankedFlights[1].count == winnerFlight.count && rankedFlights[1].country.id != winnerFlight.country.id {
                continue // tie breaker logic fails
            }
            
            let isCurrentUnknown = sortedResults[index].contributedCountries.isEmpty
            let isCurrentCalendarLow = sortedResults[index].confidenceLabel == .low && sortedResults[index].sources == .calendar && !sortedResults[index].isOverride
            
            if !sortedResults[index].isOverride && (isCurrentUnknown || isCurrentCalendarLow) {
                sortedResults[index] = promoteByOriginFlightContext(result: sortedResults[index], originFlight: winnerFlight)
            }
            
            guard index > 0 else { continue }
            if sortedResults[index - 1].contributedCountries.isEmpty {
                sortedResults[index - 1] = promoteByOriginFlightContext(
                    result: sortedResults[index - 1],
                    originFlight: winnerFlight,
                    fallbackTimeZoneId: sortedResults[index - 1].timeZoneId ?? sortedResults[index].timeZoneId
                )
            }
        }
        
        // 5. Fill backward and forward suggestions
        fillSuggestions(results: &sortedResults)

        // 6. Travel-backed transition gap infill
        applyTravelBackedTransitionInfill(results: &sortedResults, travelEvents: travelEvents)
        
        return sortedResults
    }
    
    // MARK: Compiler Utilities
    
    private func promoteByOriginFlightContext(
        result: PresenceDayResult,
        originFlight: (country: ResolvedCountry, count: Int, timeZoneId: String?),
        fallbackTimeZoneId: String? = nil
    ) -> PresenceDayResult {
        var sources = result.sources
        sources.formUnion(.calendar)
        
        var newEvidence = result.evidence
        newEvidence.append(SignalImpact(source: "CalendarFlightOriginPromotion", countryCode: originFlight.country.code, countryName: originFlight.country.name, scoreDelta: 1.0))
        
        let tz = originFlight.timeZoneId ?? fallbackTimeZoneId ?? result.timeZoneId
        let contributed = ContributedCountry(countryCode: originFlight.country.code, countryName: originFlight.country.name, probability: 1.0)
        
        return PresenceDayResult(
            dayKey: result.dayKey,
            date: result.date,
            timeZoneId: tz,
            contributedCountries: [contributed],
            zoneOverlays: result.zoneOverlays,
            evidence: newEvidence,
            confidence: max(result.confidence, 0.5),
            confidenceLabel: .medium,
            sources: sources,
            isOverride: false,
            isDisputed: result.isDisputed,
            stayCount: result.stayCount,
            photoCount: result.photoCount,
            locationCount: result.locationCount,
            calendarCount: max(result.calendarCount, originFlight.count),
            suggestedCountryCode1: result.suggestedCountryCode1,
            suggestedCountryName1: result.suggestedCountryName1,
            suggestedCountryCode2: result.suggestedCountryCode2,
            suggestedCountryName2: result.suggestedCountryName2
        )
    }

    private func promoteByAdjacentTravelContext(
        result: PresenceDayResult,
        country: ResolvedCountry,
        timeZoneId: String?,
        evidenceSource: String
    ) -> PresenceDayResult {
        var sources = result.sources
        sources.formUnion(.calendar)

        var newEvidence = result.evidence
        newEvidence.append(SignalImpact(
            source: evidenceSource,
            countryCode: country.code,
            countryName: country.name,
            scoreDelta: 1.0
        ))

        return PresenceDayResult(
            dayKey: result.dayKey,
            date: result.date,
            timeZoneId: timeZoneId ?? result.timeZoneId,
            contributedCountries: [
                ContributedCountry(countryCode: country.code, countryName: country.name, probability: 1.0)
            ],
            zoneOverlays: result.zoneOverlays,
            evidence: newEvidence,
            confidence: 0.85,
            confidenceLabel: .high,
            sources: sources,
            isOverride: false,
            isDisputed: false,
            stayCount: result.stayCount,
            photoCount: result.photoCount,
            locationCount: result.locationCount,
            calendarCount: max(result.calendarCount, 1),
            suggestedCountryCode1: result.suggestedCountryCode1,
            suggestedCountryName1: result.suggestedCountryName1,
            suggestedCountryCode2: result.suggestedCountryCode2,
            suggestedCountryName2: result.suggestedCountryName2
        )
    }

    private func promoteByTravelTransitionInfill(
        result: PresenceDayResult,
        primary: ResolvedCountry,
        secondary: ResolvedCountry
    ) -> PresenceDayResult {
        var sources = result.sources
        sources.formUnion(.calendar)

        var newEvidence = result.evidence
        newEvidence.append(SignalImpact(
            source: "CalendarTransitionInfill",
            countryCode: primary.code,
            countryName: primary.name,
            scoreDelta: 0.51
        ))

        return PresenceDayResult(
            dayKey: result.dayKey,
            date: result.date,
            timeZoneId: result.timeZoneId,
            contributedCountries: [
                ContributedCountry(countryCode: primary.code, countryName: primary.name, probability: 0.51),
                ContributedCountry(countryCode: secondary.code, countryName: secondary.name, probability: 0.49)
            ],
            zoneOverlays: result.zoneOverlays,
            evidence: newEvidence,
            confidence: 0.51,
            confidenceLabel: .medium,
            sources: sources,
            isOverride: false,
            isDisputed: true,
            stayCount: result.stayCount,
            photoCount: result.photoCount,
            locationCount: result.locationCount,
            calendarCount: max(result.calendarCount, 1),
            suggestedCountryCode1: result.suggestedCountryCode1,
            suggestedCountryName1: result.suggestedCountryName1,
            suggestedCountryCode2: result.suggestedCountryCode2,
            suggestedCountryName2: result.suggestedCountryName2
        )
    }
    
    private func bridgingContextualSmoothing(from: ContributedCountry, to: ContributedCountry, evidence: inout [SignalImpact]) {
        evidence.append(SignalImpact(source: "GapBridgingContext", countryCode: from.countryCode, countryName: from.countryName, scoreDelta: 0.5))
    }
    
    private func fillSuggestions(results: inout [PresenceDayResult]) {
        var backwardSuggestions = [ContributedCountry?](repeating: nil, count: results.count)
        var currentBackward: ContributedCountry? = nil
        for i in 0..<results.count {
            backwardSuggestions[i] = currentBackward
            if let c = results[i].contributedCountries.first { currentBackward = c }
        }
        
        var forwardSuggestions = [ContributedCountry?](repeating: nil, count: results.count)
        var currentForward: ContributedCountry? = nil
        for i in stride(from: results.count - 1, through: 0, by: -1) {
            forwardSuggestions[i] = currentForward
            if let c = results[i].contributedCountries.first { currentForward = c }
        }
        
        for i in 0..<results.count {
            if results[i].contributedCountries.isEmpty || results[i].confidence == 0 {
                var suggestions: [ContributedCountry] = []
                if let b = backwardSuggestions[i] { suggestions.append(b) }
                if let f = forwardSuggestions[i], f.countryCode != backwardSuggestions[i]?.countryCode {
                    suggestions.append(f)
                }
                if !suggestions.isEmpty {
                    results[i].suggestedCountryCode1 = suggestions[0].countryCode
                    results[i].suggestedCountryName1 = suggestions[0].countryName
                    if suggestions.count > 1 {
                        results[i].suggestedCountryCode2 = suggestions[1].countryCode
                        results[i].suggestedCountryName2 = suggestions[1].countryName
                    }
                }
            }
        }
    }

    private func buildTravelEventContexts() -> [TravelEventContext] {
        struct TravelAccumulator {
            var origin: TravelEventEndpoint?
            var destination: TravelEventEndpoint?
        }

        var grouped: [String: TravelAccumulator] = [:]

        for signal in context.calendarSignals {
            guard let baseEventIdentifier = baseTravelEventIdentifier(for: signal.eventIdentifier),
                  let country = resolveCountry(countryCode: signal.countryCode, countryName: signal.countryName) else {
                continue
            }

            let endpoint = TravelEventEndpoint(
                dayKey: signal.dayKey,
                country: country,
                timeZoneId: signal.bucketingTimeZoneId ?? signal.timeZoneId
            )

            var accumulator = grouped[baseEventIdentifier] ?? TravelAccumulator()
            if isOriginFlightSignal(signal) {
                if preferredTravelEndpoint(endpoint, over: accumulator.origin) {
                    accumulator.origin = endpoint
                }
            } else if signal.source == "Calendar" {
                if preferredTravelEndpoint(endpoint, over: accumulator.destination) {
                    accumulator.destination = endpoint
                }
            }
            grouped[baseEventIdentifier] = accumulator
        }

        return grouped.compactMap { baseEventIdentifier, accumulator in
            guard let origin = accumulator.origin, let destination = accumulator.destination else {
                return nil
            }
            return TravelEventContext(
                baseEventIdentifier: baseEventIdentifier,
                origin: origin,
                destination: destination
            )
        }
        .sorted { lhs, rhs in
            (lhs.origin.dayKey, lhs.destination.dayKey, lhs.baseEventIdentifier) <
            (rhs.origin.dayKey, rhs.destination.dayKey, rhs.baseEventIdentifier)
        }
    }

    private func applyAdjacentTravelPromotions(
        results: inout [PresenceDayResult],
        travelEvents: [TravelEventContext]
    ) {
        let indexByDayKey = Dictionary(uniqueKeysWithValues: results.enumerated().map { ($0.element.dayKey, $0.offset) })

        for travelEvent in travelEvents {
            if let previousDayKey = adjacentDayKey(
                from: travelEvent.origin.dayKey,
                timeZoneId: travelEvent.origin.timeZoneId,
                deltaDays: -1
            ), let index = indexByDayKey[previousDayKey],
               isEligibleForAdjacentTravelPromotion(results[index]) {
                results[index] = promoteByAdjacentTravelContext(
                    result: results[index],
                    country: travelEvent.origin.country,
                    timeZoneId: travelEvent.origin.timeZoneId,
                    evidenceSource: "CalendarTravelBeforePromotion"
                )
            }

            if let nextDayKey = adjacentDayKey(
                from: travelEvent.destination.dayKey,
                timeZoneId: travelEvent.destination.timeZoneId,
                deltaDays: 1
            ), let index = indexByDayKey[nextDayKey],
               isEligibleForAdjacentTravelPromotion(results[index]) {
                results[index] = promoteByAdjacentTravelContext(
                    result: results[index],
                    country: travelEvent.destination.country,
                    timeZoneId: travelEvent.destination.timeZoneId,
                    evidenceSource: "CalendarTravelAfterPromotion"
                )
            }
        }
    }

    private func applyTravelBackedTransitionInfill(
        results: inout [PresenceDayResult],
        travelEvents: [TravelEventContext]
    ) {
        var i = 0
        while i < results.count {
            if results[i].contributedCountries.isEmpty {
                var j = i
                while j < results.count, results[j].contributedCountries.isEmpty {
                    j += 1
                }

                let gapLength = j - i
                if gapLength <= 7, i > 0, j < results.count,
                   let previous = results[i - 1].contributedCountries.first,
                   let next = results[j].contributedCountries.first,
                   !countriesMatch(previous, next),
                   hasTransitionSuggestions(in: results[i..<j]),
                   hasAnchoredTravelEvent(
                    travelEvents: travelEvents,
                    previousDay: results[i - 1],
                    nextDay: results[j],
                    previousCountry: previous,
                    nextCountry: next
                   ) {
                    for k in i..<j {
                        guard let primary = resolveCountry(
                            countryCode: results[k].suggestedCountryCode1,
                            countryName: results[k].suggestedCountryName1
                        ), let secondary = resolveCountry(
                            countryCode: results[k].suggestedCountryCode2,
                            countryName: results[k].suggestedCountryName2
                        ) else {
                            continue
                        }

                        results[k] = promoteByTravelTransitionInfill(
                            result: results[k],
                            primary: primary,
                            secondary: secondary
                        )
                    }
                }
                i = j
            } else {
                i += 1
            }
        }
    }

    private func hasTransitionSuggestions(in slice: ArraySlice<PresenceDayResult>) -> Bool {
        slice.allSatisfy {
            $0.suggestedCountryCode1 != nil &&
            $0.suggestedCountryName1 != nil &&
            $0.suggestedCountryCode2 != nil &&
            $0.suggestedCountryName2 != nil
        }
    }

    private func hasAnchoredTravelEvent(
        travelEvents: [TravelEventContext],
        previousDay: PresenceDayResult,
        nextDay: PresenceDayResult,
        previousCountry: ContributedCountry,
        nextCountry: ContributedCountry
    ) -> Bool {
        travelEvents.contains { travelEvent in
            travelEvent.origin.dayKey == previousDay.dayKey &&
            travelEvent.destination.dayKey == nextDay.dayKey &&
            countriesMatch(previousCountry, travelEvent.origin.country) &&
            countriesMatch(nextCountry, travelEvent.destination.country)
        }
    }

    private func countriesMatch(_ lhs: ContributedCountry, _ rhs: ContributedCountry) -> Bool {
        if let lhsCode = lhs.countryCode, let rhsCode = rhs.countryCode {
            return lhsCode == rhsCode
        }
        return lhs.countryName.caseInsensitiveCompare(rhs.countryName) == .orderedSame
    }

    private func countriesMatch(_ lhs: ContributedCountry, _ rhs: ResolvedCountry) -> Bool {
        if let lhsCode = lhs.countryCode, let rhsCode = rhs.code {
            return lhsCode == rhsCode
        }
        return lhs.countryName.caseInsensitiveCompare(rhs.name) == .orderedSame
    }

    private func preferredTravelEndpoint(
        _ candidate: TravelEventEndpoint,
        over existing: TravelEventEndpoint?
    ) -> Bool {
        guard let existing else { return true }
        return (candidate.dayKey, candidate.country.id, candidate.timeZoneId ?? "") <
        (existing.dayKey, existing.country.id, existing.timeZoneId ?? "")
    }

    private func isOriginFlightSignal(_ signal: CalendarSignalInfo) -> Bool {
        if signal.source == "CalendarFlightOrigin" { return true }
        return signal.eventIdentifier?.hasSuffix("#origin") == true
    }

    private func baseTravelEventIdentifier(for eventIdentifier: String?) -> String? {
        guard let eventIdentifier, !eventIdentifier.isEmpty else { return nil }
        if eventIdentifier.hasSuffix("#origin") {
            return String(eventIdentifier.dropLast("#origin".count))
        }
        return eventIdentifier
    }

    private func adjacentDayKey(
        from dayKey: String,
        timeZoneId: String?,
        deltaDays: Int
    ) -> String? {
        let timeZone = DayIdentity.canonicalTimeZone(preferredTimeZoneId: timeZoneId, fallback: context.calendar.timeZone)
        guard let date = DayKey.date(for: dayKey, timeZone: timeZone) else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard let adjacent = calendar.date(byAdding: .day, value: deltaDays, to: date) else {
            return nil
        }
        return DayKey.make(from: adjacent, timeZone: timeZone)
    }

    private func isEligibleForAdjacentTravelPromotion(_ result: PresenceDayResult) -> Bool {
        guard !result.isOverride else { return false }
        guard result.contributedCountries.isEmpty else { return false }
        guard result.stayCount == 0 else { return false }
        guard result.photoCount == 0 else { return false }
        guard result.locationCount == 0 else { return false }
        return true
    }
}

struct PresenceInferenceEngine {
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
        let pipeline = PresenceInferencePipeline(middlewares: [
            StayMiddleware(),
            OverrideMiddleware(),
            PhotoMiddleware(),
            LocationMiddleware(),
            CalendarMiddleware()
        ])
        
        let context = InferenceContext(
            dayKeys: dayKeys,
            stays: stays,
            overrides: overrides,
            locations: locations,
            photos: photos,
            calendarSignals: calendarSignals,
            rangeEnd: rangeEnd,
            calendar: calendar,
            progress: progress
        )
        
        return pipeline.execute(context: context)
    }
}
