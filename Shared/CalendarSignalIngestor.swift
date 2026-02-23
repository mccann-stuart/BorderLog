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
        guard status == .authorized || status == .fullAccess else {
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

            if calendarSignalExists(eventIdentifier: event.eventIdentifier, in: modelContext) {
                 continue
            }

            var coordinate: CLLocationCoordinate2D?
            var locationString: String?

            if let structured = event.structuredLocation {
                if let geo = structured.geoLocation {
                    coordinate = geo.coordinate
                }
                locationString = structured.title
            }

            if locationString == nil {
                locationString = event.location
            }

            guard coordinate != nil || (locationString != nil && !locationString!.isEmpty) else {
                continue
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

            guard let validCountryCode = countryCode else { continue }

            let eventTimeZone = event.timeZone ?? TimeZone(identifier: timeZoneId ?? "") ?? TimeZone.current
            let dayKey = DayKey.make(from: event.startDate, timeZone: eventTimeZone)

            let signal = CalendarSignal(
                timestamp: event.startDate,
                dayKey: dayKey,
                latitude: lat,
                longitude: long,
                countryCode: validCountryCode,
                countryName: countryName,
                timeZoneId: timeZoneId ?? eventTimeZone.identifier,
                eventIdentifier: event.eventIdentifier,
                title: event.title,
                source: "Calendar"
            )

            modelContext.insert(signal)
            touchedDayKeys.insert(dayKey)
            processed += 1

            if processed % 10 == 0 {
                 try? modelContext.save()
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
}
