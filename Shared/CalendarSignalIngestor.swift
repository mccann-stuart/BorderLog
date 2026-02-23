//
//  CalendarSignalIngestor.swift
//  Learn
//
//  Created by Mccann Stuart on 17/02/2026.
//

import Foundation
import EventKit
import SwiftData
import MapKit

@ModelActor
actor CalendarSignalIngestor {
    enum IngestMode {
        case auto
        case manualFullScan
    }

    private var resolver: CountryResolving?

    init(modelContainer: ModelContainer, resolver: CountryResolving) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.resolver = resolver
    }

    func ingest(mode: IngestMode) async -> Int {
        let store = EKEventStore()

        let status = EKEventStore.authorizationStatus(for: .event)
        let hasReadAccess: Bool
        if #available(iOS 17.0, *) {
            hasReadAccess = status == .fullAccess
        } else {
            hasReadAccess = status == .authorized
        }
        guard hasReadAccess else {
            return 0
        }

        let calendar = Calendar.current
        let now = Date()

        let startDate: Date
        let endDate = now

        switch mode {
        case .manualFullScan:
            startDate = calendar.date(byAdding: .year, value: -2, to: now) ?? now
        case .auto:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        }

        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)

        // Fetch events
        let events = store.events(matching: predicate)
        let totalEvents = events.count
        let progressUpdateEvery = 10
        var didBeginScan = false
        defer {
            if didBeginScan {
                Task { @MainActor in
                    InferenceActivity.shared.endCalendarScan()
                }
            }
        }

        if totalEvents > 0 {
            await MainActor.run {
                InferenceActivity.shared.beginCalendarScan(totalEvents: totalEvents)
            }
            didBeginScan = true
        }

        var processed = 0
        var touchedDayKeys: Set<String> = []

        let activeResolver: CountryResolving
        if let storedResolver = self.resolver {
            activeResolver = storedResolver
        } else {
            let createdResolver = await MainActor.run { CLGeocoderCountryResolver() }
            activeResolver = createdResolver
            self.resolver = createdResolver
        }

        for (index, event) in events.enumerated() {
            let scannedEvents = index + 1
            if scannedEvents % progressUpdateEvery == 0 || scannedEvents == totalEvents {
                await MainActor.run {
                    InferenceActivity.shared.updateCalendarScanProgress(scannedEvents: scannedEvents)
                }
            }
            guard shouldIngest(event) else { continue }

            let (parsedFrom, parsedTo) = parseFlightInfo(event)

            // Determine Start Signal
            // Prefer parsed "From". Fallback to event location/coordinate if not parsed.
            // But if event location/coordinate matches "To", do NOT use it for Start (it's likely destination).

            var startLocationString: String? = parsedFrom
            var startCoordinate: CLLocationCoordinate2D? = nil

            if startLocationString == nil {
                if let structured = event.structuredLocation, let geo = structured.geoLocation {
                    // Use coordinate if available
                    startCoordinate = geo.coordinate
                    startLocationString = structured.title // For fallback text
                } else {
                    startLocationString = event.location
                }
            }

            // Check for destination conflict in start location
            if let to = parsedTo, let startRaw = startLocationString, !startRaw.isEmpty {
                if startRaw.localizedStandardContains(to) {
                    // The candidate start location contains the destination name.
                    // This implies the event location is actually the destination.
                    // In this case, we suppress the start signal unless we had a different coordinate?
                    // Coordinates don't have names, but structured.title does.
                    // To be safe, suppress start signal if we think it's the destination.
                    startLocationString = nil
                    startCoordinate = nil
                }
            }

            var signalsCreatedForEvent = 0

            // 1. Create Start Signal
            if startLocationString != nil || startCoordinate != nil {
                let id = event.eventIdentifier ?? event.calendarItemIdentifier
                if !calendarSignalExists(eventIdentifier: id, in: modelContext) {
                    if await resolveAndCreateSignal(
                        locationString: startLocationString,
                        coordinate: startCoordinate,
                        date: event.startDate,
                        eventIdentifier: id,
                        event: event,
                        activeResolver: activeResolver
                    ) {
                        signalsCreatedForEvent += 1
                        let dayKey = await DayKey.make(from: event.startDate, timeZone: event.timeZone ?? .current)
                        touchedDayKeys.insert(dayKey)
                    }
                }
            }

            // 2. Create End Signal (Destination)
            if let to = parsedTo {
                let id = event.eventIdentifier + "#end"
                if !calendarSignalExists(eventIdentifier: id, in: modelContext) {
                    let nextDay = calendar.date(byAdding: .day, value: 1, to: event.startDate) ?? event.endDate
                     if await resolveAndCreateSignal(
                        locationString: to,
                        coordinate: nil, // Destination usually just string unless we parsed it from somewhere else
                        date: nextDay, // Signal at arrival on the next day
                        eventIdentifier: id,
                        event: event,
                        activeResolver: activeResolver
                    ) {
                        signalsCreatedForEvent += 1
                        let dayKey = await DayKey.make(from: nextDay, timeZone: event.timeZone ?? .current)
                        touchedDayKeys.insert(dayKey)
                    }
                }
            }

            if signalsCreatedForEvent > 0 {
                processed += 1
                if processed % 10 == 0 {
                     try? modelContext.save()
                }
            }
        }

        if modelContext.hasChanges {
            try? modelContext.save()
        }

        if !touchedDayKeys.isEmpty {
            let recomputeService = LedgerRecomputeService(modelContainer: modelContainer)
            await recomputeService.recompute(dayKeys: Array(touchedDayKeys))
        }

        return processed
    }

    private func shouldIngest(_ event: EKEvent) -> Bool {
        let candidates = [
            event.title,
            event.location,
            event.structuredLocation?.title,
            event.notes
        ].compactMap { $0 }

        for text in candidates {
            if text.contains("✈") || text.localizedCaseInsensitiveContains("Flight") {
                return true
            }
        }
        return false
    }

    private func calendarSignalExists(eventIdentifier: String, in modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<CalendarSignal>(predicate: #Predicate { $0.eventIdentifier == eventIdentifier })
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    private func parseFlightInfo(_ event: EKEvent) -> (from: String?, to: String?) {
        let title = event.title ?? ""
        let notes = event.notes ?? ""

        let candidates = [title, notes]

        // Patterns
        // 1. "From A to B"
        // 2. "Flight to B"
        // 3. "A ✈ B"
        // 4. "LHR - JFK", "LHR/JFK", "JNB -> LHR", "JNB → LHR" (3-letter codes)

        // We use NSRegularExpression for compatibility
        let patternFromTo = try? NSRegularExpression(pattern: "from\\s+(.+?)\\s+to\\s+(.+)", options: [.caseInsensitive])
        let patternTo = try? NSRegularExpression(pattern: "flight\\s+to\\s+(.+)", options: [.caseInsensitive])
        let patternPlane = try? NSRegularExpression(pattern: "(.+?)\\s*✈\\s*(.+)", options: [])
        let patternPlaneEmoji = try? NSRegularExpression(pattern: "(.+?)\\s*✈️\\s*(.+)", options: [])

        // Updated to include arrows (->, →)
        let patternCodes = try? NSRegularExpression(pattern: "\\b([A-Z]{3})\\s*(?:[-/→]|->)\\s*([A-Z]{3})\\b", options: [])

        var bestFrom: String? = nil
        var bestTo: String? = nil

        for text in candidates {
            if text.isEmpty { continue }
            let nsString = text as NSString
            let range = NSRange(location: 0, length: nsString.length)

            // Priority: Find a match that gives BOTH from and to

            // Check "LHR - JFK", "LHR/JFK", "JNB -> LHR"
            if let p = patternCodes, let match = p.firstMatch(in: text, options: [], range: range) {
                if match.numberOfRanges >= 3 {
                    return (
                        nsString.substring(with: match.range(at: 1)),
                        nsString.substring(with: match.range(at: 2))
                    )
                }
            }

            // Check "A ✈ B"
            if let p = patternPlane, let match = p.firstMatch(in: text, options: [], range: range) {
                if match.numberOfRanges >= 3 {
                    return (
                        nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines),
                        nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            }

            if let p = patternPlaneEmoji, let match = p.firstMatch(in: text, options: [], range: range) {
                if match.numberOfRanges >= 3 {
                    return (
                        nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines),
                        nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            }

            // Check "From A to B"
            if let p = patternFromTo, let match = p.firstMatch(in: text, options: [], range: range) {
                if match.numberOfRanges >= 3 {
                    return (
                        nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines),
                        nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            }

            // Check "Flight to B" (Only yields 'to')
            // Don't return immediately, try to find a better match in other candidates
            if bestTo == nil {
                if let p = patternTo, let match = p.firstMatch(in: text, options: [], range: range) {
                    if match.numberOfRanges >= 2 {
                        bestTo = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }

        return (bestFrom, bestTo)
    }

    private func resolveAndCreateSignal(
        locationString: String?,
        coordinate: CLLocationCoordinate2D?,
        date: Date,
        eventIdentifier: String,
        event: EKEvent,
        activeResolver: CountryResolving
    ) async -> Bool {
        guard coordinate != nil || (locationString != nil && !locationString!.isEmpty) else {
            return false
        }

        var countryCode: String?
        var countryName: String?
        var timeZoneId: String?
        var lat: Double = 0
        var long: Double = 0

        if let coord = coordinate {
            lat = coord.latitude
            long = coord.longitude
            let location = CLLocation(latitude: lat, longitude: long)
            let resolution = await activeResolver.resolveCountry(for: location)
            countryCode = resolution?.countryCode
            countryName = resolution?.countryName
            timeZoneId = resolution?.timeZone?.identifier
        } else if let locString = locationString {
            // First try to resolve as an airport code
            if let airport = await AirportCodeResolver.shared.resolve(code: locString) {
                lat = airport.lat
                long = airport.lon
                countryCode = airport.country
                countryName = Locale.current.localizedString(forRegionCode: airport.country)
                // TimeZone: Fallback to event timezone or infer from country?
                // Event timezone is a safe bet for calendar events.
            } else {
                // Rate limit manually: 1 request per second max
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = locString
                let search = MKLocalSearch(request: request)

                if let response = try? await search.start(),
                   let item = response.mapItems.first {
                    let loc = item.location
                    lat = loc.coordinate.latitude
                    long = loc.coordinate.longitude
                    countryCode = item.addressRepresentations?.region?.identifier
                    countryName = item.addressRepresentations?.regionName
                    timeZoneId = item.timeZone?.identifier
                }
            }
        }

        guard let validCountryCode = countryCode else { return false }

        let eventTimeZone = event.timeZone ?? TimeZone(identifier: timeZoneId ?? "") ?? TimeZone.current
        let dayKey = await DayKey.make(from: date, timeZone: eventTimeZone)

        let signal = CalendarSignal(
            timestamp: date,
            dayKey: dayKey,
            latitude: lat,
            longitude: long,
            countryCode: validCountryCode,
            countryName: countryName,
            timeZoneId: timeZoneId ?? eventTimeZone.identifier,
            eventIdentifier: eventIdentifier,
            title: event.title,
            source: "Calendar"
        )

        modelContext.insert(signal)
        return true
    }
}
