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

    enum IngestMode: Equatable {
        case auto
        case manualFullScan
        case selectionRebuild
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

    struct PrimarySignalSelection {
        let locationString: String?
        let coordinate: CLLocationCoordinate2D?
        let date: Date
        let usesDestinationRule: Bool
    }

    private var resolver: CountryResolving?
    private var recoveryStore: LedgerRecomputeRecoveryStore = .shared
    private var calendarSelectionStore: CalendarSourceSelectionStore = .shared
    internal var saveContextOverride: (@Sendable () throws -> Void)?

    init(
        modelContainer: ModelContainer,
        resolver: CountryResolving,
        recoveryStore: LedgerRecomputeRecoveryStore = .shared,
        calendarSelectionStore: CalendarSourceSelectionStore = CalendarSourceSelectionStore()
    ) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.resolver = resolver
        self.recoveryStore = recoveryStore
        self.calendarSelectionStore = calendarSelectionStore
    }

    func ingest(mode: IngestMode) async throws -> Int {
        let store = EKEventStore()

        guard hasReadAccess() else {
            return 0
        }

        let selectedCalendars = try fetchSelectedCalendars(from: store)

        let effectiveMode = effectiveIngestMode(for: mode)

        let now = Date()
        let ingestEndDate = now
        let ingestStartDate = ingestStartDate(for: effectiveMode, now: now)

        let events: [EKEvent]
        if selectedCalendars.isEmpty {
            events = []
        } else {
            let predicate = store.predicateForEvents(
                withStart: ingestStartDate,
                end: ingestEndDate,
                calendars: selectedCalendars
            )
            events = store.events(matching: predicate)
        }
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

        let staleWindowEnd = Calendar.current.date(byAdding: .day, value: 1, to: ingestEndDate) ?? ingestEndDate
        let existingSignals: [CalendarSignal]
        if effectiveMode == .selectionRebuild {
            existingSignals = try modelContext.fetch(FetchDescriptor<CalendarSignal>())
        } else {
            existingSignals = try modelContext.fetch(
                FetchDescriptor<CalendarSignal>(
                    predicate: #Predicate { signal in
                        signal.timestamp >= ingestStartDate && signal.timestamp <= staleWindowEnd
                    }
                )
            )
        }

        var existingSignalByIdentifier = existingSignals.reduce(into: [String: CalendarSignal](minimumCapacity: existingSignals.count)) { result, signal in
            result[signal.eventIdentifier] = signal
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

            let mutated = await processEvent(
                event,
                activeResolver: activeResolver,
                existingSignalByIdentifier: &existingSignalByIdentifier,
                seenIdentifiers: &seenIdentifiers,
                touchedDayKeys: &touchedDayKeys
            )
            if mutated {
                processed += 1
                if processed % 10 == 0 {
                    recoveryStore.markDirty(dayKeys: touchedDayKeys)
                    try saveContextIfNeeded()
                }
            }
        }

        let orphanDeletes = deleteOrphanedSignals(
            existingSignalByIdentifier: &existingSignalByIdentifier,
            seenIdentifiers: seenIdentifiers,
            touchedDayKeys: &touchedDayKeys
        )
        if orphanDeletes > 0 {
            processed += orphanDeletes
        }

        recoveryStore.markDirty(dayKeys: touchedDayKeys)
        try saveContextIfNeeded()

        if !touchedDayKeys.isEmpty {
            let recomputeService = LedgerRecomputeService(modelContainer: modelContainer)
            await recomputeService.setRecoveryStore(recoveryStore)
            try await recomputeService.recompute(dayKeys: Array(touchedDayKeys))
        }

        if effectiveMode == .selectionRebuild {
            calendarSelectionStore.markRebuildCompleted()
        }

        return processed
    }

    func effectiveIngestMode(for requestedMode: IngestMode) -> IngestMode {
        calendarSelectionStore.needsRebuild ? .selectionRebuild : requestedMode
    }

    private func processEvent(
        _ event: EKEvent,
        activeResolver: CountryResolving,
        existingSignalByIdentifier: inout [String: CalendarSignal],
        seenIdentifiers: inout Set<String>,
        touchedDayKeys: inout Set<String>
    ) async -> Bool {
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

            return eventMutations > 0
        }

        guard let eventStartDate = event.startDate else { return false }
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

        return eventMutations > 0
    }

    private func ingestStartDate(for mode: IngestMode, now: Date) -> Date {
        let calendar = Calendar.current
        switch mode {
        case .manualFullScan, .selectionRebuild:
            return calendar.date(byAdding: .year, value: -2, to: now) ?? now
        case .auto:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        }
    }

    private func fetchSelectedCalendars(from store: EKEventStore) throws -> [EKCalendar] {
        let availableCalendars = store.calendars(for: .event)
        let storedSelection = calendarSelectionStore.load()
        let availableReferences = availableCalendars.map(calendarReference(for:))
        let selectionResolution = storedSelection.resolve(available: availableReferences)
        if selectionResolution.migratedSelection != storedSelection {
            try calendarSelectionStore.save(selectionResolution.migratedSelection, markingRebuild: false)
        }
        return availableCalendars.filter {
            selectionResolution.selectedIdentifiers.contains($0.calendarIdentifier)
        }
    }

    private func hasReadAccess() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    func deleteOrphanedSignals(
        existingSignalByIdentifier: inout [String: CalendarSignal],
        seenIdentifiers: Set<String>,
        touchedDayKeys: inout Set<String>
    ) -> Int {
        let orphanIdentifiers = existingSignalByIdentifier.keys.filter {
            !seenIdentifiers.contains($0)
        }
        for identifier in orphanIdentifiers {
            guard let signal = existingSignalByIdentifier.removeValue(forKey: identifier) else {
                continue
            }
            touchedDayKeys.insert(signal.dayKey)
            modelContext.delete(signal)
        }
        return orphanIdentifiers.count
    }

    private func calendarReference(for calendar: EKCalendar) -> CalendarSourceReference {
        CalendarSourceReference(
            identifier: calendar.calendarIdentifier,
            title: calendar.title,
            sourceIdentifier: calendar.source.sourceIdentifier,
            sourceTitle: calendar.source.title
        )
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

    func selectPrimarySignalInput(
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

        if let startLocation = nonEmptyLocation(parsedFrom) {
            return PrimarySignalSelection(
                locationString: startLocation,
                coordinate: nil,
                date: eventStartDate,
                usesDestinationRule: false
            )
        }

        if let structuredCoordinate {
            return PrimarySignalSelection(
                locationString: nonEmptyLocation(structuredLocationTitle),
                coordinate: structuredCoordinate,
                date: eventStartDate,
                usesDestinationRule: false
            )
        }

        return PrimarySignalSelection(
            locationString: nonEmptyLocation(eventLocation),
            coordinate: nil,
            date: eventStartDate,
            usesDestinationRule: false
        )
    }

    func shouldPersistOriginSignal(
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








    private func saveContextIfNeeded() throws {
        guard modelContext.hasChanges else { return }
        if let saveContextOverride {
            try saveContextOverride()
        } else {
            try modelContext.save()
        }
    }
}
