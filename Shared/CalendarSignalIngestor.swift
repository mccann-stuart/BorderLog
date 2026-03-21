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
    private static let primarySignalSource = "Calendar"
    private static let flightPrimarySignalSource = "CalendarFlight"
    private static let flightOriginSignalSource = "CalendarFlightOrigin"
    private static let originSignalSuffix = "#origin"
    private static let legacyEndSignalSuffix = "#end"

    enum IngestMode {
        case auto
        case manualFullScan
    }

    struct ResolvedCalendarSignal: Sendable {
        let timestamp: Date
        let dayKey: String
        let timeZoneId: String
        let bucketingTimeZoneId: String
        let latitude: Double
        let longitude: Double
        let countryCode: String
        let countryName: String
    }

    private struct PrimarySignalSelection {
        let locationString: String?
        let coordinate: CLLocationCoordinate2D?
        let date: Date
        let usesDestinationRule: Bool
    }

    private var resolver: CountryResolving?
    internal var saveContextOverride: (@Sendable () throws -> Void)?

    init(modelContainer: ModelContainer, resolver: CountryResolving) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.resolver = resolver
    }

    func ingest(mode: IngestMode) async throws -> Int {
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

        let ingestStartDate: Date
        let ingestEndDate = now

        switch mode {
        case .manualFullScan:
            ingestStartDate = calendar.date(byAdding: .year, value: -2, to: now) ?? now
        case .auto:
            ingestStartDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        }

        let predicate = store.predicateForEvents(withStart: ingestStartDate, end: ingestEndDate, calendars: nil)
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

        let staleWindowEnd = calendar.date(byAdding: .day, value: 1, to: ingestEndDate) ?? ingestEndDate
        let existingSignals = try modelContext.fetch(
            FetchDescriptor<CalendarSignal>(
                predicate: #Predicate { signal in
                    signal.timestamp >= ingestStartDate && signal.timestamp <= staleWindowEnd
                }
            )
        )

        var existingSignalByIdentifier: [String: CalendarSignal] = [:]
        for signal in existingSignals {
            existingSignalByIdentifier[signal.eventIdentifier] = signal
        }

        var seenIdentifiers = Set<String>()

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

            let id = event.eventIdentifier ?? event.calendarItemIdentifier
            let originId = id + Self.originSignalSuffix
            let endId = id + Self.legacyEndSignalSuffix
            var eventMutations = 0
            let snapshot = eventSnapshot(for: event)
            let ingestability = classify(snapshot)

            guard ingestability.shouldIngest else {
                eventMutations += deleteSignalIfExists(
                    identifier: id,
                    existingSignalByIdentifier: &existingSignalByIdentifier,
                    touchedDayKeys: &touchedDayKeys
                )
                eventMutations += deleteSignalIfExists(
                    identifier: originId,
                    existingSignalByIdentifier: &existingSignalByIdentifier,
                    touchedDayKeys: &touchedDayKeys
                )
                eventMutations += deleteSignalIfExists(
                    identifier: endId,
                    existingSignalByIdentifier: &existingSignalByIdentifier,
                    touchedDayKeys: &touchedDayKeys
                )
                seenIdentifiers.insert(id)
                seenIdentifiers.insert(originId)
                seenIdentifiers.insert(endId)

                if eventMutations > 0 {
                    processed += 1
                    if processed % 10 == 0 {
                        try saveContextIfNeeded()
                    }
                }
                continue
            }

            guard let eventStartDate = event.startDate else { continue }
            let (parsedFrom, parsedTo) = parseFlightInfo(snapshot)
            let primarySelection = selectPrimarySignalInput(
                parsedFrom: parsedFrom,
                parsedTo: parsedTo,
                eventStartDate: eventStartDate,
                eventEndDate: event.endDate,
                structuredLocationTitle: event.structuredLocation?.title,
                structuredCoordinate: event.structuredLocation?.geoLocation?.coordinate,
                eventLocation: event.location
            )

            let startResolved = await resolveSignal(
                locationString: primarySelection.locationString,
                coordinate: primarySelection.coordinate,
                date: primarySelection.date,
                event: event,
                activeResolver: activeResolver
            )

            let originResolved: ResolvedCalendarSignal?
            if ingestability.shouldDecorateAsFlight,
               primarySelection.usesDestinationRule,
               let originLocation = nonEmptyLocation(parsedFrom) {
                originResolved = await resolveSignal(
                    locationString: originLocation,
                    coordinate: nil,
                    date: eventStartDate,
                    event: event,
                    activeResolver: activeResolver
                )
            } else {
                originResolved = nil
            }

            seenIdentifiers.insert(id)
            if let startResolved {
                if upsertSignal(
                    identifier: id,
                    resolved: startResolved,
                    title: event.title,
                    source: ingestability.shouldDecorateAsFlight ? Self.flightPrimarySignalSource : Self.primarySignalSource,
                    existingSignalByIdentifier: &existingSignalByIdentifier,
                    touchedDayKeys: &touchedDayKeys
                ) {
                    eventMutations += 1
                }
            } else {
                eventMutations += deleteSignalIfExists(
                    identifier: id,
                    existingSignalByIdentifier: &existingSignalByIdentifier,
                    touchedDayKeys: &touchedDayKeys
                )
            }

            seenIdentifiers.insert(originId)
            let shouldPersistOriginSignal = shouldPersistOriginSignal(
                originResolved: originResolved
            )
            if shouldPersistOriginSignal, let originResolved {
                if upsertSignal(
                    identifier: originId,
                    resolved: originResolved,
                    title: event.title,
                    source: Self.flightOriginSignalSource,
                    existingSignalByIdentifier: &existingSignalByIdentifier,
                    touchedDayKeys: &touchedDayKeys
                ) {
                    eventMutations += 1
                }
            } else {
                eventMutations += deleteSignalIfExists(
                    identifier: originId,
                    existingSignalByIdentifier: &existingSignalByIdentifier,
                    touchedDayKeys: &touchedDayKeys
                )
            }

            seenIdentifiers.insert(endId)
            eventMutations += deleteSignalIfExists(
                identifier: endId,
                existingSignalByIdentifier: &existingSignalByIdentifier,
                touchedDayKeys: &touchedDayKeys
            )

            if eventMutations > 0 {
                processed += 1
                if processed % 10 == 0 {
                    try saveContextIfNeeded()
                }
            }
        }

        var orphanDeletes = 0
        for (identifier, signal) in existingSignalByIdentifier {
            guard !seenIdentifiers.contains(identifier) else { continue }
            touchedDayKeys.insert(signal.dayKey)
            modelContext.delete(signal)
            orphanDeletes += 1
        }
        if orphanDeletes > 0 {
            processed += orphanDeletes
        }

        try saveContextIfNeeded()

        if !touchedDayKeys.isEmpty {
            let recomputeService = LedgerRecomputeService(modelContainer: modelContainer)
            await recomputeService.recompute(dayKeys: Array(touchedDayKeys))
        }

        return processed
    }

    private func eventSnapshot(for event: EKEvent) -> CalendarEventTextSnapshot {
        CalendarEventTextSnapshot(
            title: event.title,
            location: event.location,
            structuredLocationTitle: event.structuredLocation?.title,
            notes: event.notes
        )
    }

    private func classify(_ snapshot: CalendarEventTextSnapshot) -> CalendarEventIngestability {
        CalendarFlightParsing.classify(event: snapshot)
    }

    private func parseFlightInfo(_ snapshot: CalendarEventTextSnapshot) -> (from: String?, to: String?) {
        CalendarFlightParsing.parseFlightInfo(event: snapshot)
    }

    private func selectPrimarySignalInput(
        parsedFrom: String?,
        parsedTo: String?,
        eventStartDate: Date,
        eventEndDate: Date?,
        structuredLocationTitle: String?,
        structuredCoordinate: CLLocationCoordinate2D?,
        eventLocation: String?
    ) -> PrimarySignalSelection {
        if let destination = nonEmptyLocation(parsedTo) {
            return PrimarySignalSelection(
                locationString: destination,
                coordinate: nil,
                date: eventEndDate ?? eventStartDate,
                usesDestinationRule: true
            )
        }

        var startLocationString = nonEmptyLocation(parsedFrom)
        var startCoordinate: CLLocationCoordinate2D? = nil

        if startLocationString == nil {
            if let structuredCoordinate {
                startCoordinate = structuredCoordinate
                startLocationString = nonEmptyLocation(structuredLocationTitle)
            } else {
                startLocationString = nonEmptyLocation(eventLocation)
            }
        }

        return PrimarySignalSelection(
            locationString: startLocationString,
            coordinate: startCoordinate,
            date: eventStartDate,
            usesDestinationRule: false
        )
    }

    private func shouldPersistOriginSignal(
        originResolved: ResolvedCalendarSignal?
    ) -> Bool {
        return originResolved != nil
    }

    private func nonEmptyLocation(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func resolveSignal(
        locationString: String?,
        coordinate: CLLocationCoordinate2D?,
        date: Date,
        event: EKEvent,
        activeResolver: CountryResolving
    ) async -> ResolvedCalendarSignal? {
        guard coordinate != nil || (locationString != nil && !locationString!.isEmpty) else {
            return nil
        }

        var countryCode: String?
        var countryName: String?
        var resolvedTimeZoneId: String?
        var latitude: Double = 0
        var longitude: Double = 0

        if let coordinate {
            latitude = coordinate.latitude
            longitude = coordinate.longitude
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let resolution = await activeResolver.resolveCountry(for: location)
            countryCode = resolution?.countryCode
            countryName = resolution?.countryName
            resolvedTimeZoneId = resolution?.timeZone?.identifier
        } else if let locationString {
            if let airport = await AirportCodeResolver.shared.resolve(code: locationString) {
                latitude = airport.lat
                longitude = airport.lon
                countryCode = airport.country
                countryName = Locale.current.localizedString(forRegionCode: airport.country)
            } else {
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = locationString
                let search = MKLocalSearch(request: request)

                if let response = try? await search.start(),
                   let item = response.mapItems.first {
                    let location = item.location
                    latitude = location.coordinate.latitude
                    longitude = location.coordinate.longitude
                    countryCode = item.addressRepresentations?.region?.identifier
                    countryName = item.addressRepresentations?.regionName
                    resolvedTimeZoneId = item.timeZone?.identifier
                }
            }
        }

        guard let resolution = CountryResolution.normalized(
            countryCode: countryCode,
            countryName: countryName,
            timeZone: resolvedTimeZoneId.flatMap(TimeZone.init(identifier:))
        ), let resolvedCountryName = resolution.countryName,
        let resolvedCountryCode = resolution.countryCode else {
            return nil
        }

        let bucketingTimeZone = DayIdentity.canonicalTimeZone(
            preferredTimeZoneId: resolvedTimeZoneId ?? event.timeZone?.identifier
        )
        let dayKey = DayKey.make(from: date, timeZone: bucketingTimeZone)

        return ResolvedCalendarSignal(
            timestamp: date,
            dayKey: dayKey,
            timeZoneId: bucketingTimeZone.identifier,
            bucketingTimeZoneId: bucketingTimeZone.identifier,
            latitude: latitude,
            longitude: longitude,
            countryCode: resolvedCountryCode,
            countryName: resolvedCountryName
        )
    }

    func upsertSignal(
        identifier: String,
        resolved: ResolvedCalendarSignal,
        title: String?,
        source: String = "Calendar",
        existingSignalByIdentifier: inout [String: CalendarSignal],
        touchedDayKeys: inout Set<String>
    ) -> Bool {
        if let existing = existingSignalByIdentifier[identifier] {
            var didChange = false

            if existing.dayKey != resolved.dayKey {
                touchedDayKeys.insert(existing.dayKey)
                existing.dayKey = resolved.dayKey
                didChange = true
            }
            if existing.timestamp != resolved.timestamp {
                existing.timestamp = resolved.timestamp
                didChange = true
            }
            if existing.latitude != resolved.latitude {
                existing.latitude = resolved.latitude
                didChange = true
            }
            if existing.longitude != resolved.longitude {
                existing.longitude = resolved.longitude
                didChange = true
            }
            if existing.countryCode != resolved.countryCode {
                existing.countryCode = resolved.countryCode
                didChange = true
            }
            if existing.countryName != resolved.countryName {
                existing.countryName = resolved.countryName
                didChange = true
            }
            if existing.timeZoneId != resolved.timeZoneId {
                existing.timeZoneId = resolved.timeZoneId
                didChange = true
            }
            if existing.bucketingTimeZoneId != resolved.bucketingTimeZoneId {
                existing.bucketingTimeZoneId = resolved.bucketingTimeZoneId
                didChange = true
            }
            if existing.title != title {
                existing.title = title
                didChange = true
            }
            if existing.source != source {
                existing.source = source
                didChange = true
            }

            if didChange {
                touchedDayKeys.insert(resolved.dayKey)
            }
            return didChange
        }

        let signal = CalendarSignal(
            timestamp: resolved.timestamp,
            dayKey: resolved.dayKey,
            latitude: resolved.latitude,
            longitude: resolved.longitude,
            countryCode: resolved.countryCode,
            countryName: resolved.countryName,
            timeZoneId: resolved.timeZoneId,
            bucketingTimeZoneId: resolved.bucketingTimeZoneId,
            eventIdentifier: identifier,
            title: title,
            source: source
        )
        modelContext.insert(signal)
        existingSignalByIdentifier[identifier] = signal
        touchedDayKeys.insert(resolved.dayKey)
        return true
    }

    func deleteSignalIfExists(
        identifier: String,
        existingSignalByIdentifier: inout [String: CalendarSignal],
        touchedDayKeys: inout Set<String>
    ) -> Int {
        guard let stale = existingSignalByIdentifier.removeValue(forKey: identifier) else {
            return 0
        }
        touchedDayKeys.insert(stale.dayKey)
        modelContext.delete(stale)
        return 1
    }

    func testUpsertScenario(
        existingDayKey: String,
        resolved: ResolvedCalendarSignal
    ) -> (
        changed: Bool,
        touchedDayKeys: [String],
        finalDayKey: String,
        finalTimeZoneId: String?,
        finalBucketingTimeZoneId: String?
    ) {
        let existing = CalendarSignal(
            timestamp: Date(timeIntervalSince1970: 0),
            dayKey: existingDayKey,
            latitude: 0,
            longitude: 0,
            countryCode: "GB",
            countryName: "United Kingdom",
            timeZoneId: "UTC",
            bucketingTimeZoneId: "UTC",
            eventIdentifier: "event-1",
            title: "Old",
            source: "Calendar"
        )
        var map: [String: CalendarSignal] = ["event-1": existing]
        var touchedDayKeys = Set<String>()
        let changed = upsertSignal(
            identifier: "event-1",
            resolved: resolved,
            title: "New",
            existingSignalByIdentifier: &map,
            touchedDayKeys: &touchedDayKeys
        )
        let updated = map["event-1"] ?? existing
        return (
            changed: changed,
            touchedDayKeys: touchedDayKeys.sorted(),
            finalDayKey: updated.dayKey,
            finalTimeZoneId: updated.timeZoneId,
            finalBucketingTimeZoneId: updated.bucketingTimeZoneId
        )
    }

    func testDeleteScenario(existingDayKey: String) -> (deleted: Int, touchedDayKeys: [String], remaining: Int) {
        let existing = CalendarSignal(
            timestamp: Date(timeIntervalSince1970: 0),
            dayKey: existingDayKey,
            latitude: 0,
            longitude: 0,
            countryCode: "GB",
            countryName: "United Kingdom",
            timeZoneId: "UTC",
            bucketingTimeZoneId: "UTC",
            eventIdentifier: "event-2",
            title: "Old",
            source: "Calendar"
        )
        var map: [String: CalendarSignal] = ["event-2": existing]
        var touchedDayKeys = Set<String>()
        let deleted = deleteSignalIfExists(
            identifier: "event-2",
            existingSignalByIdentifier: &map,
            touchedDayKeys: &touchedDayKeys
        )
        return (deleted: deleted, touchedDayKeys: touchedDayKeys.sorted(), remaining: map.count)
    }

    func testPrimarySignalSelection(
        parsedFrom: String?,
        parsedTo: String?,
        eventStartDate: Date,
        eventEndDate: Date?,
        structuredLocationTitle: String?,
        structuredCoordinate: CLLocationCoordinate2D?,
        eventLocation: String?
    ) -> (locationString: String?, usesDestinationRule: Bool, date: Date, usesCoordinate: Bool) {
        let selection = selectPrimarySignalInput(
            parsedFrom: parsedFrom,
            parsedTo: parsedTo,
            eventStartDate: eventStartDate,
            eventEndDate: eventEndDate,
            structuredLocationTitle: structuredLocationTitle,
            structuredCoordinate: structuredCoordinate,
            eventLocation: eventLocation
        )
        return (
            locationString: selection.locationString,
            usesDestinationRule: selection.usesDestinationRule,
            date: selection.date,
            usesCoordinate: selection.coordinate != nil
        )
    }

    func testShouldPersistOriginSignal(
        originDayKey: String,
        destinationDayKey: String?,
        eventStartDate: Date,
        eventEndDate: Date?,
        eventTimeZoneId: String?
    ) -> Bool {
        let originResolved = ResolvedCalendarSignal(
            timestamp: eventStartDate,
            dayKey: originDayKey,
            timeZoneId: "UTC",
            bucketingTimeZoneId: "UTC",
            latitude: 0,
            longitude: 0,
            countryCode: "GB",
            countryName: "United Kingdom"
        )
        _ = destinationDayKey
        _ = eventEndDate
        _ = eventTimeZoneId
        return shouldPersistOriginSignal(originResolved: originResolved)
    }

    func testDestinationFirstLegacyEndCleanup(
        existingDayKey: String,
        resolved: ResolvedCalendarSignal
    ) -> (changed: Bool, deletedLegacyEnd: Int, remainingIdentifiers: [String]) {
        let legacyPrimary = CalendarSignal(
            timestamp: Date(timeIntervalSince1970: 0),
            dayKey: existingDayKey,
            latitude: 0,
            longitude: 0,
            countryCode: "GB",
            countryName: "United Kingdom",
            timeZoneId: "UTC",
            bucketingTimeZoneId: "UTC",
            eventIdentifier: "event-3",
            title: "Old",
            source: "Calendar"
        )
        let legacyEnd = CalendarSignal(
            timestamp: Date(timeIntervalSince1970: 0),
            dayKey: existingDayKey,
            latitude: 0,
            longitude: 0,
            countryCode: "DE",
            countryName: "Germany",
            timeZoneId: "UTC",
            bucketingTimeZoneId: "UTC",
            eventIdentifier: "event-3#end",
            title: "Old End",
            source: "Calendar"
        )
        var map: [String: CalendarSignal] = [
            "event-3": legacyPrimary,
            "event-3#end": legacyEnd
        ]
        var touchedDayKeys = Set<String>()
        let changed = upsertSignal(
            identifier: "event-3",
            resolved: resolved,
            title: "New",
            existingSignalByIdentifier: &map,
            touchedDayKeys: &touchedDayKeys
        )
        let deletedLegacyEnd = deleteSignalIfExists(
            identifier: "event-3#end",
            existingSignalByIdentifier: &map,
            touchedDayKeys: &touchedDayKeys
        )
        return (
            changed: changed,
            deletedLegacyEnd: deletedLegacyEnd,
            remainingIdentifiers: map.keys.sorted()
        )
    }

    private func saveContextIfNeeded() throws {
        guard modelContext.hasChanges else { return }
        if let saveContextOverride {
            try saveContextOverride()
        } else {
            try modelContext.save()
        }
    }
}
