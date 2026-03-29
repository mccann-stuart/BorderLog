//
//  PresenceInferenceEngine.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation

struct ResolvedCountry: Hashable, Sendable {
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

struct InferencePipelineConfig: Sendable {
    let stayBaseWeight: Double = 5.0
    let photoBaseWeight: Double = 2.0
    let locationBaseWeight: Double = 3.0
    let calendarBaseWeight: Double = 1.0
    let overrideWeight: Double = 1_000.0
    let resolutionThreshold: Double = 1.0
    let allocationFloor: Double = 0.05
    let disputeShareMarginThreshold: Double = 0.35
    let gapBridgeMaxDays: Int = 7
    let highConfidenceScore: Double = 5.0
    let mediumConfidenceScore: Double = 2.0
    let adjacentTravelWinningShare: Double = 0.85
    let originPromotionWinningShare: Double = 0.55
    let transitionPrimaryShare: Double = 0.51
    let transitionSecondaryShare: Double = 0.49
    let gapBridgeShare: Double = 0.5
    let locationAccuracyReference: Double = 100.0
    let locationMinDecayFactor: Double = 0.2
    let locationMaxDecayFactor: Double = 1.0
    let contextualDecayFactor: Double = 0.5

    func calibratedLocationWeight(for accuracyMeters: Double) -> Double {
        let accuracy = max(accuracyMeters, 1)
        let factor = min(
            locationMaxDecayFactor,
            max(locationMinDecayFactor, locationAccuracyReference / accuracy)
        )
        return locationBaseWeight * factor
    }

    func confidenceLabel(for winningScore: Double, winningShare: Double) -> ConfidenceLabel {
        if winningScore >= highConfidenceScore || winningShare >= 0.85 {
            return .high
        }
        if winningScore >= mediumConfidenceScore || winningShare >= 0.5 {
            return .medium
        }
        return .low
    }
}

struct InferenceSourceCounts: Sendable {
    var stayCount = 0
    var photoCount = 0
    var locationCount = 0
    var calendarCount = 0
}

struct FlightOriginCandidate: Sendable {
    let country: ResolvedCountry
    var count: Int
    let timeZoneId: String?
}

struct DayInferenceState: Sendable {
    var countryScores: [String: Double] = [:]
    var countries: [String: ResolvedCountry] = [:]
    var timeZoneScores: [String: Double] = [:]
    var counts = InferenceSourceCounts()
    var evidenceEntries: [PresenceEvidenceEntry] = []
    var overrideInfo: OverridePresenceInfo?
    var flightOriginCandidates: [String: FlightOriginCandidate] = [:]
}

struct InferencePipelineState: Sendable {
    var days: [String: DayInferenceState]

    init(dayKeys: Set<String>) {
        self.days = Dictionary(uniqueKeysWithValues: dayKeys.map { ($0, DayInferenceState()) })
    }

    subscript(dayKey: String) -> DayInferenceState {
        get { days[dayKey] ?? DayInferenceState() }
        set { days[dayKey] = newValue }
    }

    mutating func recordMutation(
        dayKey: String,
        processorID: String,
        country: ResolvedCountry,
        rawWeight: Double,
        calibratedWeight: Double,
        phase: PresenceEvidencePhase,
        reason: String,
        timeZoneId: String?,
        contributesToScore: Bool = true
    ) {
        var dayState = self[dayKey]
        dayState.countries[country.id] = country
        if contributesToScore {
            dayState.countryScores[country.id, default: 0] += calibratedWeight
            if let timeZoneId, TimeZone(identifier: timeZoneId) != nil {
                dayState.timeZoneScores[timeZoneId, default: 0] += calibratedWeight
            }
            incrementCount(for: processorID, counts: &dayState.counts)
        }
        dayState.evidenceEntries.append(
            PresenceEvidenceEntry(
                dayKey: dayKey,
                processorID: processorID,
                countryCode: country.code,
                countryName: country.name,
                rawWeight: rawWeight,
                calibratedWeight: calibratedWeight,
                phase: phase,
                reason: reason,
                contributedToFinalResult: false,
                timeZoneId: timeZoneId
            )
        )
        self[dayKey] = dayState
    }

    mutating func recordOverride(dayKey: String, overrideInfo: OverridePresenceInfo, country: ResolvedCountry, weight: Double) {
        var dayState = self[dayKey]
        dayState.overrideInfo = overrideInfo
        if TimeZone(identifier: overrideInfo.dayTimeZoneId) != nil {
            dayState.timeZoneScores[overrideInfo.dayTimeZoneId, default: 0] += weight
        }
        dayState.evidenceEntries.append(
            PresenceEvidenceEntry(
                dayKey: dayKey,
                processorID: "override",
                countryCode: country.code,
                countryName: country.name,
                rawWeight: weight,
                calibratedWeight: weight,
                phase: .override,
                reason: "manual-override",
                contributedToFinalResult: true,
                timeZoneId: overrideInfo.dayTimeZoneId
            )
        )
        self[dayKey] = dayState
    }

    mutating func recordFlightOriginCandidate(dayKey: String, country: ResolvedCountry, timeZoneId: String?, reason: String) {
        var dayState = self[dayKey]
        var candidate = dayState.flightOriginCandidates[country.id] ?? FlightOriginCandidate(country: country, count: 0, timeZoneId: timeZoneId)
        candidate.count += 1
        dayState.flightOriginCandidates[country.id] = candidate
        dayState.evidenceEntries.append(
            PresenceEvidenceEntry(
                dayKey: dayKey,
                processorID: "calendar.origin",
                countryCode: country.code,
                countryName: country.name,
                rawWeight: 0,
                calibratedWeight: 0,
                phase: .contextual,
                reason: reason,
                contributedToFinalResult: false,
                timeZoneId: timeZoneId
            )
        )
        self[dayKey] = dayState
    }

    private mutating func incrementCount(for processorID: String, counts: inout InferenceSourceCounts) {
        let normalized = processorID.lowercased()
        if normalized.contains("stay") {
            counts.stayCount += 1
        } else if normalized.contains("photo") {
            counts.photoCount += 1
        } else if normalized.contains("location") {
            counts.locationCount += 1
        } else if normalized.contains("calendar") {
            counts.calendarCount += 1
        }
    }
}

protocol SignalProcessor {
    var id: String { get }
    func process(state: inout InferencePipelineState, context: InferenceContext, config: InferencePipelineConfig)
}

struct InferencePipeline {
    let config: InferencePipelineConfig
    let processors: [SignalProcessor]

    func execute(context: InferenceContext) -> [PresenceDayResult] {
        var state = InferencePipelineState(dayKeys: context.dayKeys)
        for processor in processors {
            processor.process(state: &state, context: context, config: config)
        }
        return PresenceResultCompiler(context: context, config: config).compile(state: state)
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

fileprivate func countryMatches(_ lhs: PresenceCountryAllocation, _ rhs: PresenceCountryAllocation) -> Bool {
    if let lhsCode = lhs.countryCode, let rhsCode = rhs.countryCode {
        return lhsCode == rhsCode
    }
    return lhs.countryName.caseInsensitiveCompare(rhs.countryName) == .orderedSame
}

fileprivate func countryMatches(_ lhs: PresenceCountryAllocation, _ rhs: ResolvedCountry) -> Bool {
    if let lhsCode = lhs.countryCode, let rhsCode = rhs.code {
        return lhsCode == rhsCode
    }
    return lhs.countryName.caseInsensitiveCompare(rhs.name) == .orderedSame
}

// MARK: - Processors

struct StayProcessor: SignalProcessor {
    let id = "stay"

    func process(state: inout InferencePipelineState, context: InferenceContext, config: InferencePipelineConfig) {
        let defaultTimeZone = context.calendar.timeZone
        for stay in context.stays {
            guard let country = resolveCountry(countryCode: stay.countryCode, countryName: stay.countryName) else { continue }
            let stayTimeZone = DayIdentity.canonicalTimeZone(preferredTimeZoneId: stay.dayTimeZoneId, fallback: defaultTimeZone)
            guard let start = DayKey.date(for: stay.entryDayKey, timeZone: stayTimeZone) else { continue }

            let rangeEndKey = DayKey.make(from: context.rangeEnd, timeZone: stayTimeZone)
            let clampedRangeEnd = DayKey.date(for: rangeEndKey, timeZone: stayTimeZone) ?? context.rangeEnd
            let exitKey = stay.exitDayKey ?? rangeEndKey
            let rawEnd = DayKey.date(for: exitKey, timeZone: stayTimeZone) ?? clampedRangeEnd
            let end = min(rawEnd, clampedRangeEnd)
            guard start <= end else { continue }

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = stayTimeZone

            var day = start
            while day <= end {
                let dayKey = DayKey.make(from: day, timeZone: stayTimeZone)
                if context.dayKeys.contains(dayKey) {
                    state.recordMutation(
                        dayKey: dayKey,
                        processorID: id,
                        country: country,
                        rawWeight: config.stayBaseWeight,
                        calibratedWeight: config.stayBaseWeight,
                        phase: .base,
                        reason: "stay-coverage",
                        timeZoneId: stay.dayTimeZoneId
                    )
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
    }
}

struct OverrideProcessor: SignalProcessor {
    let id = "override"

    func process(state: inout InferencePipelineState, context: InferenceContext, config: InferencePipelineConfig) {
        for overrideDay in context.overrides {
            guard context.dayKeys.contains(overrideDay.dayKey),
                  let country = resolveCountry(countryCode: overrideDay.countryCode, countryName: overrideDay.countryName) else {
                continue
            }
            state.recordOverride(dayKey: overrideDay.dayKey, overrideInfo: overrideDay, country: country, weight: config.overrideWeight)
        }
    }
}

struct PhotoProcessor: SignalProcessor {
    let id = "photo"

    func process(state: inout InferencePipelineState, context: InferenceContext, config: InferencePipelineConfig) {
        for photo in context.photos where context.dayKeys.contains(photo.dayKey) {
            guard let country = resolveCountry(countryCode: photo.countryCode, countryName: photo.countryName) else { continue }
            state.recordMutation(
                dayKey: photo.dayKey,
                processorID: id,
                country: country,
                rawWeight: config.photoBaseWeight,
                calibratedWeight: config.photoBaseWeight,
                phase: .base,
                reason: "photo-signal",
                timeZoneId: photo.timeZoneId
            )
        }
    }
}

struct LocationProcessor: SignalProcessor {
    let id = "location"

    func process(state: inout InferencePipelineState, context: InferenceContext, config: InferencePipelineConfig) {
        for location in context.locations where context.dayKeys.contains(location.dayKey) {
            guard let country = resolveCountry(countryCode: location.countryCode, countryName: location.countryName) else { continue }
            let calibratedWeight = config.calibratedLocationWeight(for: location.accuracyMeters)
            state.recordMutation(
                dayKey: location.dayKey,
                processorID: id,
                country: country,
                rawWeight: config.locationBaseWeight,
                calibratedWeight: calibratedWeight,
                phase: .base,
                reason: "location-accuracy:\(Int(location.accuracyMeters.rounded()))m",
                timeZoneId: location.timeZoneId
            )
        }
    }
}

struct CalendarProcessor: SignalProcessor {
    let id = "calendar"

    func process(state: inout InferencePipelineState, context: InferenceContext, config: InferencePipelineConfig) {
        for signal in context.calendarSignals {
            guard let country = resolveCountry(countryCode: signal.countryCode, countryName: signal.countryName) else { continue }
            if isOriginFlightSignal(signal) {
                state.recordFlightOriginCandidate(
                    dayKey: signal.dayKey,
                    country: country,
                    timeZoneId: signal.bucketingTimeZoneId ?? signal.timeZoneId,
                    reason: "flight-origin-candidate"
                )
                continue
            }

            guard context.dayKeys.contains(signal.dayKey) else { continue }
            state.recordMutation(
                dayKey: signal.dayKey,
                processorID: id,
                country: country,
                rawWeight: config.calendarBaseWeight,
                calibratedWeight: config.calendarBaseWeight,
                phase: .base,
                reason: signal.source ?? "calendar-signal",
                timeZoneId: signal.bucketingTimeZoneId ?? signal.timeZoneId
            )
        }
    }

    private func isOriginFlightSignal(_ signal: CalendarSignalInfo) -> Bool {
        if signal.source == "CalendarFlightOrigin" { return true }
        return signal.eventIdentifier?.hasSuffix("#origin") == true
    }
}

// MARK: - Compiler

private struct PresenceResultCompiler {
    let context: InferenceContext
    let config: InferencePipelineConfig

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

    func compile(state: InferencePipelineState) -> [PresenceDayResult] {
        let defaultTimeZone = context.calendar.timeZone
        let orderedDayKeys = context.dayKeys.sorted()

        var results: [PresenceDayResult] = []
        results.reserveCapacity(orderedDayKeys.count)

        for (index, dayKey) in orderedDayKeys.enumerated() {
            if let progress = context.progress {
                progress(index + 1, orderedDayKeys.count)
            }

            let dayState = state.days[dayKey] ?? DayInferenceState()
            let selectedTimeZoneId = selectedDayTimeZoneId(
                for: dayState,
                preferredTimeZoneId: dayState.overrideInfo?.dayTimeZoneId,
                fallback: defaultTimeZone.identifier
            )
            let dayTimeZone = TimeZone(identifier: selectedTimeZoneId) ?? defaultTimeZone
            let date = DayKey.date(for: dayKey, timeZone: dayTimeZone) ?? context.calendar.startOfDay(for: context.rangeEnd)
            results.append(baseResult(for: dayKey, date: date, timeZoneId: dayTimeZone.identifier, dayState: dayState))
        }

        var sortedResults = results.sorted { $0.date < $1.date }
        applyGapBridging(results: &sortedResults)

        let travelEvents = buildTravelEventContexts()
        applyAdjacentTravelPromotions(results: &sortedResults, travelEvents: travelEvents)
        applyOriginFlightPromotions(results: &sortedResults, state: state)
        fillSuggestions(results: &sortedResults)
        applyTravelBackedTransitionInfill(results: &sortedResults, travelEvents: travelEvents)

        return sortedResults.map(markContributingEvidence)
    }

    private func baseResult(for dayKey: String, date: Date, timeZoneId: String?, dayState: DayInferenceState) -> PresenceDayResult {
        let sourceSummary = SignalSourceMask.from(processorIDs: dayState.evidenceEntries.map(\.processorID))

        if let overrideInfo = dayState.overrideInfo,
           let country = resolveCountry(countryCode: overrideInfo.countryCode, countryName: overrideInfo.countryName) {
            return PresenceDayResult(
                dayKey: dayKey,
                date: date,
                timeZoneId: timeZoneId,
                countryAllocations: [PresenceCountryAllocation(countryCode: country.code, countryName: country.name, normalizedShare: 1.0)],
                zoneOverlays: [],
                evidenceEntries: dayState.evidenceEntries,
                confidenceBreakdown: PresenceConfidenceBreakdown(
                    score: config.overrideWeight,
                    runnerUpScore: 0,
                    margin: 1,
                    normalizedWinningShare: 1,
                    label: .high,
                    calibrationSummary: "manual override"
                ),
                sourceSummary: sourceSummary,
                isOverride: true,
                isDisputed: false,
                stayCount: dayState.counts.stayCount,
                photoCount: dayState.counts.photoCount,
                locationCount: dayState.counts.locationCount,
                calendarCount: dayState.counts.calendarCount
            )
        }

        // ⚡ Bolt: Replace O(N log N) sorting + reduce + multiple passes with a single O(N) loop
        var totalScore: Double = 0
        var winner: (country: ResolvedCountry, score: Double)?
        var runnerUp: (country: ResolvedCountry, score: Double)?

        for (key, score) in dayState.countryScores {
            guard let country = dayState.countries[key] else { continue }
            totalScore += score

            let current = (country: country, score: score)
            if let w = winner {
                if score > w.score || (score == w.score && country.id < w.country.id) {
                    runnerUp = winner
                    winner = current
                } else if let r = runnerUp {
                    if score > r.score || (score == r.score && country.id < r.country.id) {
                        runnerUp = current
                    }
                } else {
                    runnerUp = current
                }
            } else {
                winner = current
            }
        }

        guard let winner = winner, winner.score >= config.resolutionThreshold, totalScore > 0 else {
            return PresenceDayResult(
                dayKey: dayKey,
                date: date,
                timeZoneId: timeZoneId,
                countryAllocations: [],
                zoneOverlays: [],
                evidenceEntries: dayState.evidenceEntries,
                confidenceBreakdown: PresenceConfidenceBreakdown(
                    score: winner?.score ?? 0,
                    runnerUpScore: runnerUp?.score ?? 0,
                    margin: 0,
                    normalizedWinningShare: 0,
                    label: .low,
                    calibrationSummary: "below-threshold"
                ),
                sourceSummary: sourceSummary,
                isOverride: false,
                isDisputed: false,
                stayCount: dayState.counts.stayCount,
                photoCount: dayState.counts.photoCount,
                locationCount: dayState.counts.locationCount,
                calendarCount: dayState.counts.calendarCount
            )
        }

        let runnerUpScore = runnerUp?.score ?? 0
        let winningShare = winner.score / totalScore
        let runnerUpShare = runnerUpScore / totalScore
        let margin = max(0, winningShare - runnerUpShare)

        // ⚡ Bolt: Use a single compactMap pass to generate allocations above the floor without O(N) intermediate filtering
        let allocations: [PresenceCountryAllocation] = dayState.countryScores.compactMap { key, score in
            guard let country = dayState.countries[key] else { return nil }
            let normalizedShare = score / totalScore
            guard normalizedShare >= config.allocationFloor else { return nil }
            return PresenceCountryAllocation(
                countryCode: country.code,
                countryName: country.name,
                normalizedShare: normalizedShare
            )
        }.sorted { $0.normalizedShare > $1.normalizedShare || ($0.normalizedShare == $1.normalizedShare && $0.countryCode < $1.countryCode) }

        return PresenceDayResult(
            dayKey: dayKey,
            date: date,
            timeZoneId: timeZoneId,
            countryAllocations: allocations,
            zoneOverlays: [],
            evidenceEntries: dayState.evidenceEntries,
            confidenceBreakdown: PresenceConfidenceBreakdown(
                score: winner.score,
                runnerUpScore: runnerUpScore,
                margin: margin,
                normalizedWinningShare: winningShare,
                label: config.confidenceLabel(for: winner.score, winningShare: winningShare),
                calibrationSummary: "calibrated totals"
            ),
            sourceSummary: sourceSummary,
            isOverride: false,
            isDisputed: allocations.count > 1 && margin <= config.disputeShareMarginThreshold,
            stayCount: dayState.counts.stayCount,
            photoCount: dayState.counts.photoCount,
            locationCount: dayState.counts.locationCount,
            calendarCount: dayState.counts.calendarCount
        )
    }

    private func selectedDayTimeZoneId(for dayState: DayInferenceState, preferredTimeZoneId: String?, fallback: String) -> String {
        if let preferredTimeZoneId, TimeZone(identifier: preferredTimeZoneId) != nil {
            return preferredTimeZoneId
        }
        return dayState.timeZoneScores.max(by: { lhs, rhs in
            lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
        })?.key ?? fallback
    }

    private func applyGapBridging(results: inout [PresenceDayResult]) {
        var i = 0
        while i < results.count {
            if results[i].countryAllocations.isEmpty {
                var j = i
                while j < results.count, results[j].countryAllocations.isEmpty {
                    j += 1
                }

                let gapLength = j - i
                if gapLength <= config.gapBridgeMaxDays, i > 0, j < results.count,
                   let previous = results[i - 1].countryAllocations.first,
                   let next = results[j].countryAllocations.first,
                   countryMatches(previous, next) {
                    for index in i..<j {
                        results[index] = makeContextualResult(
                            from: results[index],
                            allocations: [PresenceCountryAllocation(countryCode: previous.countryCode, countryName: previous.countryName, normalizedShare: 1.0)],
                            evidenceEntry: PresenceEvidenceEntry(
                                dayKey: results[index].dayKey,
                                processorID: "GapBridgingContext",
                                countryCode: previous.countryCode,
                                countryName: previous.countryName,
                                rawWeight: config.gapBridgeShare,
                                calibratedWeight: config.gapBridgeShare,
                                phase: .contextual,
                                reason: "GapBridgingContext",
                                contributedToFinalResult: true,
                                timeZoneId: results[index].timeZoneId
                            ),
                            confidenceBreakdown: PresenceConfidenceBreakdown(
                                score: config.gapBridgeShare,
                                runnerUpScore: 0,
                                margin: config.gapBridgeShare,
                                normalizedWinningShare: config.gapBridgeShare,
                                label: .medium,
                                calibrationSummary: "contextual gap bridge"
                            ),
                            sourceSummary: .none,
                            isDisputed: false
                        )
                    }
                }
                i = j
            } else {
                i += 1
            }
        }
    }

    private func applyOriginFlightPromotions(results: inout [PresenceDayResult], state: InferencePipelineState) {
        for index in results.indices {
            let dayKey = results[index].dayKey
            guard let dayState = state.days[dayKey] else { continue }

            // ⚡ Bolt: Replace O(N log N) sorting with a single O(N) Top-2 Selection pass
            var winner: FlightOriginCandidate?
            var runnerUp: FlightOriginCandidate?

            for candidate in dayState.flightOriginCandidates.values {
                if let w = winner {
                    if candidate.count > w.count || (candidate.count == w.count && candidate.country.id < w.country.id) {
                        runnerUp = winner
                        winner = candidate
                    } else if let r = runnerUp {
                        if candidate.count > r.count || (candidate.count == r.count && candidate.country.id < r.country.id) {
                            runnerUp = candidate
                        }
                    } else {
                        runnerUp = candidate
                    }
                } else {
                    winner = candidate
                }
            }

            guard let winner = winner else { continue }
            if let runnerUp = runnerUp, runnerUp.count == winner.count, runnerUp.country.id != winner.country.id {
                continue
            }

            if isEligibleForOriginFlightPromotion(results[index]) {
                results[index] = makeContextualResult(
                    from: results[index],
                    allocations: [PresenceCountryAllocation(countryCode: winner.country.code, countryName: winner.country.name, normalizedShare: 1.0)],
                    evidenceEntry: PresenceEvidenceEntry(
                        dayKey: results[index].dayKey,
                        processorID: "CalendarFlightOriginPromotion",
                        countryCode: winner.country.code,
                        countryName: winner.country.name,
                        rawWeight: config.originPromotionWinningShare,
                        calibratedWeight: config.originPromotionWinningShare,
                        phase: .contextual,
                        reason: "CalendarFlightOriginPromotion",
                        contributedToFinalResult: true,
                        timeZoneId: winner.timeZoneId ?? results[index].timeZoneId
                    ),
                    confidenceBreakdown: PresenceConfidenceBreakdown(
                        score: config.originPromotionWinningShare,
                        runnerUpScore: 0,
                        margin: config.originPromotionWinningShare,
                        normalizedWinningShare: config.originPromotionWinningShare,
                        label: .medium,
                        calibrationSummary: "origin flight context"
                    ),
                    sourceSummary: results[index].sources.union(.calendar),
                    isDisputed: false,
                    timeZoneId: winner.timeZoneId ?? results[index].timeZoneId,
                    calendarCount: max(results[index].calendarCount, winner.count)
                )
            }

            guard index > 0, results[index - 1].countryAllocations.isEmpty else { continue }
            results[index - 1] = makeContextualResult(
                from: results[index - 1],
                allocations: [PresenceCountryAllocation(countryCode: winner.country.code, countryName: winner.country.name, normalizedShare: 1.0)],
                evidenceEntry: PresenceEvidenceEntry(
                    dayKey: results[index - 1].dayKey,
                    processorID: "CalendarFlightOriginPromotion",
                    countryCode: winner.country.code,
                    countryName: winner.country.name,
                    rawWeight: config.originPromotionWinningShare,
                    calibratedWeight: config.originPromotionWinningShare,
                    phase: .contextual,
                    reason: "CalendarFlightOriginPromotion",
                    contributedToFinalResult: true,
                    timeZoneId: winner.timeZoneId ?? results[index - 1].timeZoneId
                ),
                confidenceBreakdown: PresenceConfidenceBreakdown(
                    score: config.originPromotionWinningShare,
                    runnerUpScore: 0,
                    margin: config.originPromotionWinningShare,
                    normalizedWinningShare: config.originPromotionWinningShare,
                    label: .medium,
                    calibrationSummary: "origin flight context"
                ),
                sourceSummary: results[index - 1].sources.union(.calendar),
                isDisputed: false,
                timeZoneId: winner.timeZoneId ?? results[index - 1].timeZoneId,
                calendarCount: max(results[index - 1].calendarCount, winner.count)
            )
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
            } else {
                if preferredTravelEndpoint(endpoint, over: accumulator.destination) {
                    accumulator.destination = endpoint
                }
            }
            grouped[baseEventIdentifier] = accumulator
        }

        return grouped.compactMap { baseEventIdentifier, accumulator in
            guard let origin = accumulator.origin, let destination = accumulator.destination else { return nil }
            return TravelEventContext(baseEventIdentifier: baseEventIdentifier, origin: origin, destination: destination)
        }
        .sorted { lhs, rhs in
            (lhs.origin.dayKey, lhs.destination.dayKey, lhs.baseEventIdentifier) <
            (rhs.origin.dayKey, rhs.destination.dayKey, rhs.baseEventIdentifier)
        }
    }

    private func applyAdjacentTravelPromotions(results: inout [PresenceDayResult], travelEvents: [TravelEventContext]) {
        let indexByDayKey = Dictionary(uniqueKeysWithValues: results.enumerated().map { ($0.element.dayKey, $0.offset) })
        for travelEvent in travelEvents {
            if let previousDayKey = adjacentDayKey(from: travelEvent.origin.dayKey, timeZoneId: travelEvent.origin.timeZoneId, deltaDays: -1),
               let index = indexByDayKey[previousDayKey],
               isEligibleForAdjacentTravelPromotion(results[index]) {
                results[index] = makeContextualResult(
                    from: results[index],
                    allocations: [PresenceCountryAllocation(countryCode: travelEvent.origin.country.code, countryName: travelEvent.origin.country.name, normalizedShare: 1.0)],
                    evidenceEntry: PresenceEvidenceEntry(
                        dayKey: results[index].dayKey,
                        processorID: "CalendarTravelBeforePromotion",
                        countryCode: travelEvent.origin.country.code,
                        countryName: travelEvent.origin.country.name,
                        rawWeight: config.adjacentTravelWinningShare,
                        calibratedWeight: config.adjacentTravelWinningShare,
                        phase: .contextual,
                        reason: "CalendarTravelBeforePromotion",
                        contributedToFinalResult: true,
                        timeZoneId: travelEvent.origin.timeZoneId
                    ),
                    confidenceBreakdown: PresenceConfidenceBreakdown(
                        score: config.adjacentTravelWinningShare,
                        runnerUpScore: 0,
                        margin: config.adjacentTravelWinningShare,
                        normalizedWinningShare: config.adjacentTravelWinningShare,
                        label: .high,
                        calibrationSummary: "adjacent travel before"
                    ),
                    sourceSummary: results[index].sources.union(.calendar),
                    isDisputed: false,
                    timeZoneId: travelEvent.origin.timeZoneId,
                    calendarCount: max(results[index].calendarCount, 1)
                )
            }

            if let nextDayKey = adjacentDayKey(from: travelEvent.destination.dayKey, timeZoneId: travelEvent.destination.timeZoneId, deltaDays: 1),
               let index = indexByDayKey[nextDayKey],
               isEligibleForAdjacentTravelPromotion(results[index]) {
                results[index] = makeContextualResult(
                    from: results[index],
                    allocations: [PresenceCountryAllocation(countryCode: travelEvent.destination.country.code, countryName: travelEvent.destination.country.name, normalizedShare: 1.0)],
                    evidenceEntry: PresenceEvidenceEntry(
                        dayKey: results[index].dayKey,
                        processorID: "CalendarTravelAfterPromotion",
                        countryCode: travelEvent.destination.country.code,
                        countryName: travelEvent.destination.country.name,
                        rawWeight: config.adjacentTravelWinningShare,
                        calibratedWeight: config.adjacentTravelWinningShare,
                        phase: .contextual,
                        reason: "CalendarTravelAfterPromotion",
                        contributedToFinalResult: true,
                        timeZoneId: travelEvent.destination.timeZoneId
                    ),
                    confidenceBreakdown: PresenceConfidenceBreakdown(
                        score: config.adjacentTravelWinningShare,
                        runnerUpScore: 0,
                        margin: config.adjacentTravelWinningShare,
                        normalizedWinningShare: config.adjacentTravelWinningShare,
                        label: .high,
                        calibrationSummary: "adjacent travel after"
                    ),
                    sourceSummary: results[index].sources.union(.calendar),
                    isDisputed: false,
                    timeZoneId: travelEvent.destination.timeZoneId,
                    calendarCount: max(results[index].calendarCount, 1)
                )
            }
        }
    }

    private func fillSuggestions(results: inout [PresenceDayResult]) {
        var backwardSuggestions = [PresenceCountryAllocation?](repeating: nil, count: results.count)
        var currentBackward: PresenceCountryAllocation?
        for index in results.indices {
            backwardSuggestions[index] = currentBackward
            if let current = results[index].countryAllocations.first {
                currentBackward = current
            }
        }

        var forwardSuggestions = [PresenceCountryAllocation?](repeating: nil, count: results.count)
        var currentForward: PresenceCountryAllocation?
        if !results.isEmpty {
            for index in stride(from: results.count - 1, through: 0, by: -1) {
                forwardSuggestions[index] = currentForward
                if let current = results[index].countryAllocations.first {
                    currentForward = current
                }
            }
        }

        for index in results.indices where results[index].countryAllocations.isEmpty || results[index].confidence == 0 {
            var suggestions: [PresenceCountryAllocation] = []
            if let backward = backwardSuggestions[index] {
                suggestions.append(backward)
            }
            if let forward = forwardSuggestions[index],
               suggestions.contains(where: { countryMatches($0, forward) }) == false {
                suggestions.append(forward)
            }

            guard !suggestions.isEmpty else { continue }
            results[index] = PresenceDayResult(
                dayKey: results[index].dayKey,
                date: results[index].date,
                timeZoneId: results[index].timeZoneId,
                countryAllocations: results[index].countryAllocations,
                zoneOverlays: results[index].zoneOverlays,
                evidenceEntries: results[index].evidenceEntries,
                confidenceBreakdown: results[index].confidenceBreakdown,
                sourceSummary: results[index].sources,
                isOverride: results[index].isOverride,
                isDisputed: results[index].isDisputed,
                stayCount: results[index].stayCount,
                photoCount: results[index].photoCount,
                locationCount: results[index].locationCount,
                calendarCount: results[index].calendarCount,
                suggestedCountryCode1: suggestions[0].countryCode,
                suggestedCountryName1: suggestions[0].countryName,
                suggestedCountryCode2: suggestions.dropFirst().first?.countryCode,
                suggestedCountryName2: suggestions.dropFirst().first?.countryName
            )
        }
    }

    private func applyTravelBackedTransitionInfill(results: inout [PresenceDayResult], travelEvents: [TravelEventContext]) {
        var i = 0
        while i < results.count {
            if results[i].countryAllocations.isEmpty {
                var j = i
                while j < results.count, results[j].countryAllocations.isEmpty {
                    j += 1
                }

                let gapLength = j - i
                if gapLength <= config.gapBridgeMaxDays,
                   i > 0, j < results.count,
                   let previous = results[i - 1].countryAllocations.first,
                   let next = results[j].countryAllocations.first,
                   !countryMatches(previous, next),
                   hasTransitionSuggestions(in: results[i..<j]),
                   hasAnchoredTravelEvent(travelEvents: travelEvents, previousDay: results[i - 1], nextDay: results[j], previousCountry: previous, nextCountry: next) {
                    for index in i..<j {
                        guard let primary = resolveCountry(countryCode: results[index].suggestedCountryCode1, countryName: results[index].suggestedCountryName1),
                              let secondary = resolveCountry(countryCode: results[index].suggestedCountryCode2, countryName: results[index].suggestedCountryName2) else {
                            continue
                        }
                        results[index] = makeContextualResult(
                            from: results[index],
                            allocations: [
                                PresenceCountryAllocation(countryCode: primary.code, countryName: primary.name, normalizedShare: config.transitionPrimaryShare),
                                PresenceCountryAllocation(countryCode: secondary.code, countryName: secondary.name, normalizedShare: config.transitionSecondaryShare)
                            ],
                            evidenceEntry: PresenceEvidenceEntry(
                                dayKey: results[index].dayKey,
                                processorID: "CalendarTransitionInfill",
                                countryCode: primary.code,
                                countryName: primary.name,
                                rawWeight: config.transitionPrimaryShare,
                                calibratedWeight: config.transitionPrimaryShare,
                                phase: .contextual,
                                reason: "CalendarTransitionInfill",
                                contributedToFinalResult: true,
                                timeZoneId: results[index].timeZoneId
                            ),
                            confidenceBreakdown: PresenceConfidenceBreakdown(
                                score: config.transitionPrimaryShare,
                                runnerUpScore: config.transitionSecondaryShare,
                                margin: config.transitionPrimaryShare - config.transitionSecondaryShare,
                                normalizedWinningShare: config.transitionPrimaryShare,
                                label: .medium,
                                calibrationSummary: "travel-backed transition"
                            ),
                            sourceSummary: results[index].sources.union(.calendar),
                            isDisputed: true,
                            calendarCount: max(results[index].calendarCount, 1)
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
        previousCountry: PresenceCountryAllocation,
        nextCountry: PresenceCountryAllocation
    ) -> Bool {
        travelEvents.contains { travelEvent in
            travelEvent.origin.dayKey == previousDay.dayKey &&
            travelEvent.destination.dayKey == nextDay.dayKey &&
            countryMatches(previousCountry, travelEvent.origin.country) &&
            countryMatches(nextCountry, travelEvent.destination.country)
        }
    }

    private func makeContextualResult(
        from result: PresenceDayResult,
        allocations: [PresenceCountryAllocation],
        evidenceEntry: PresenceEvidenceEntry,
        confidenceBreakdown: PresenceConfidenceBreakdown,
        sourceSummary: SignalSourceMask,
        isDisputed: Bool,
        timeZoneId: String? = nil,
        calendarCount: Int? = nil
    ) -> PresenceDayResult {
        PresenceDayResult(
            dayKey: result.dayKey,
            date: result.date,
            timeZoneId: timeZoneId ?? result.timeZoneId,
            countryAllocations: allocations,
            zoneOverlays: result.zoneOverlays,
            evidenceEntries: result.evidenceEntries + [evidenceEntry],
            confidenceBreakdown: confidenceBreakdown,
            sourceSummary: sourceSummary,
            isOverride: false,
            isDisputed: isDisputed,
            stayCount: result.stayCount,
            photoCount: result.photoCount,
            locationCount: result.locationCount,
            calendarCount: calendarCount ?? result.calendarCount,
            suggestedCountryCode1: result.suggestedCountryCode1,
            suggestedCountryName1: result.suggestedCountryName1,
            suggestedCountryCode2: result.suggestedCountryCode2,
            suggestedCountryName2: result.suggestedCountryName2
        )
    }

    private func markContributingEvidence(_ result: PresenceDayResult) -> PresenceDayResult {
        let selectedCountries = result.countryAllocations
        let updatedEvidence = result.evidenceEntries.map { entry in
            var mutable = entry
            mutable.contributedToFinalResult =
                selectedCountries.contains(where: { allocation in
                    if let countryCode = entry.countryCode, let allocationCode = allocation.countryCode {
                        return countryCode == allocationCode
                    }
                    return entry.countryName.caseInsensitiveCompare(allocation.countryName) == .orderedSame
                }) || entry.phase == .override
            return mutable
        }

        return PresenceDayResult(
            dayKey: result.dayKey,
            date: result.date,
            timeZoneId: result.timeZoneId,
            countryAllocations: result.countryAllocations,
            zoneOverlays: result.zoneOverlays,
            evidenceEntries: updatedEvidence,
            confidenceBreakdown: result.confidenceBreakdown,
            sourceSummary: result.sourceSummary,
            isOverride: result.isOverride,
            isDisputed: result.isDisputed,
            stayCount: result.stayCount,
            photoCount: result.photoCount,
            locationCount: result.locationCount,
            calendarCount: result.calendarCount,
            suggestedCountryCode1: result.suggestedCountryCode1,
            suggestedCountryName1: result.suggestedCountryName1,
            suggestedCountryCode2: result.suggestedCountryCode2,
            suggestedCountryName2: result.suggestedCountryName2
        )
    }

    private func isEligibleForAdjacentTravelPromotion(_ result: PresenceDayResult) -> Bool {
        guard !result.isOverride else { return false }
        guard result.stayCount == 0, result.photoCount == 0, result.locationCount == 0 else { return false }
        if result.countryAllocations.isEmpty {
            return true
        }
        return result.sources == .calendar && result.confidenceLabel == .low
    }

    private func isEligibleForOriginFlightPromotion(_ result: PresenceDayResult) -> Bool {
        isEligibleForAdjacentTravelPromotion(result)
    }

    private func preferredTravelEndpoint(_ candidate: TravelEventEndpoint, over existing: TravelEventEndpoint?) -> Bool {
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

    private func adjacentDayKey(from dayKey: String, timeZoneId: String?, deltaDays: Int) -> String? {
        let timeZone = DayIdentity.canonicalTimeZone(preferredTimeZoneId: timeZoneId, fallback: context.calendar.timeZone)
        guard let date = DayKey.date(for: dayKey, timeZone: timeZone) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let adjacent = calendar.date(byAdding: .day, value: deltaDays, to: date) else { return nil }
        return DayKey.make(from: adjacent, timeZone: timeZone)
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
        let pipeline = InferencePipeline(
            config: InferencePipelineConfig(),
            processors: [
                StayProcessor(),
                OverrideProcessor(),
                PhotoProcessor(),
                LocationProcessor(),
                CalendarProcessor()
            ]
        )

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
