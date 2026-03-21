#if canImport(XCTest)
import XCTest
@testable import Learn

final class CalendarEvidenceResolverTests: XCTestCase {
    private func makePresenceDay(
        dayKey: String,
        date: Date,
        timeZoneId: String,
        countryCode: String?,
        countryName: String?,
        confidence: Double,
        confidenceLabel: ConfidenceLabel,
        sources: SignalSourceMask,
        isOverride: Bool = false,
        stayCount: Int = 0,
        photoCount: Int = 0,
        locationCount: Int = 0,
        calendarCount: Int
    ) -> PresenceDay {
        let contributedCountries: [ContributedCountry]
        if let countryName {
            contributedCountries = [
                ContributedCountry(countryCode: countryCode, countryName: countryName, probability: 1.0)
            ]
        } else {
            contributedCountries = []
        }

        return PresenceDay(
            dayKey: dayKey,
            date: date,
            timeZoneId: timeZoneId,
            contributedCountries: contributedCountries,
            zoneOverlays: [],
            evidence: [],
            confidence: confidence,
            confidenceLabel: confidenceLabel,
            sources: sources,
            isOverride: isOverride,
            stayCount: stayCount,
            photoCount: photoCount,
            locationCount: locationCount,
            calendarCount: calendarCount
        )
    }

    func testResolveUsesAdjacentOriginFlightForCalendarInferredDayWithoutSameDaySignals() {
        let day = makePresenceDay(
            dayKey: "2026-03-14",
            date: Date(timeIntervalSince1970: 1_000),
            timeZoneId: "Europe/London",
            countryCode: "GB",
            countryName: "United Kingdom",
            confidence: 0.5,
            confidenceLabel: .medium,
            sources: .calendar,
            isOverride: false,
            stayCount: 0,
            photoCount: 0,
            locationCount: 0,
            calendarCount: 1
        )

        let adjacentSignals = [
            CalendarSignal(
                timestamp: Date(timeIntervalSince1970: 2_000),
                dayKey: "2026-03-15",
                latitude: 51.4700,
                longitude: -0.4543,
                countryCode: "GB",
                countryName: "United Kingdom",
                timeZoneId: "Europe/London",
                eventIdentifier: "flight-1#origin",
                title: "Flight to San Francisco",
                source: "CalendarFlightOrigin"
            ),
            CalendarSignal(
                timestamp: Date(timeIntervalSince1970: 30_000),
                dayKey: "2026-03-15",
                latitude: 37.6213,
                longitude: -122.3790,
                countryCode: "US",
                countryName: "United States",
                timeZoneId: "America/Los_Angeles",
                eventIdentifier: "flight-1",
                title: "Flight to San Francisco",
                source: "Calendar"
            )
        ]

        let resolved = CalendarEvidenceResolver.resolve(
            sameDaySignals: [],
            adjacentSignals: adjacentSignals,
            dayCountryCode: day.countryCode,
            dayCountryName: day.countryName,
            calendarCount: day.calendarCount,
            sources: day.sources
        )

        XCTAssertEqual(resolved.map(\.eventIdentifier), ["flight-1#origin"])
    }

    func testResolveFallsBackToAdjacentOriginFlightWhenDayIsStillUnknown() {
        let day = makePresenceDay(
            dayKey: "2026-03-14",
            date: Date(timeIntervalSince1970: 1_000),
            timeZoneId: "Europe/London",
            countryCode: nil,
            countryName: nil,
            confidence: 0.2,
            confidenceLabel: .low,
            sources: .calendar,
            isOverride: false,
            stayCount: 0,
            photoCount: 0,
            locationCount: 0,
            calendarCount: 1
        )

        let adjacentSignals = [
            CalendarSignal(
                timestamp: Date(timeIntervalSince1970: 2_000),
                dayKey: "2026-03-15",
                latitude: 51.4700,
                longitude: -0.4543,
                countryCode: "GB",
                countryName: "United Kingdom",
                timeZoneId: "Europe/London",
                eventIdentifier: "flight-1#origin",
                title: "Flight to San Francisco",
                source: "CalendarFlightOrigin"
            )
        ]

        let resolved = CalendarEvidenceResolver.resolve(
            sameDaySignals: [],
            adjacentSignals: adjacentSignals,
            dayCountryCode: day.countryCode,
            dayCountryName: day.countryName,
            calendarCount: day.calendarCount,
            sources: day.sources
        )

        XCTAssertEqual(resolved.map(\.eventIdentifier), ["flight-1#origin"])
    }

    func testResolveKeepsSameDayCalendarSignalsWithoutPullingAdjacentOriginSignals() {
        let day = makePresenceDay(
            dayKey: "2026-03-15",
            date: Date(timeIntervalSince1970: 1_000),
            timeZoneId: "Europe/London",
            countryCode: "US",
            countryName: "United States",
            confidence: 0.3,
            confidenceLabel: .low,
            sources: .calendar,
            isOverride: false,
            stayCount: 0,
            photoCount: 0,
            locationCount: 0,
            calendarCount: 1
        )

        let sameDaySignals = [
            CalendarSignal(
                timestamp: Date(timeIntervalSince1970: 2_000),
                dayKey: "2026-03-15",
                latitude: 37.6213,
                longitude: -122.3790,
                countryCode: "US",
                countryName: "United States",
                timeZoneId: "America/Los_Angeles",
                eventIdentifier: "flight-1",
                title: "Flight to San Francisco",
                source: "Calendar"
            )
        ]

        let adjacentSignals = [
            CalendarSignal(
                timestamp: Date(timeIntervalSince1970: 1_500),
                dayKey: "2026-03-14",
                latitude: 51.4700,
                longitude: -0.4543,
                countryCode: "GB",
                countryName: "United Kingdom",
                timeZoneId: "Europe/London",
                eventIdentifier: "flight-1#origin",
                title: "Flight to San Francisco",
                source: "CalendarFlightOrigin"
            )
        ]

        let resolved = CalendarEvidenceResolver.resolve(
            sameDaySignals: sameDaySignals,
            adjacentSignals: adjacentSignals,
            dayCountryCode: day.countryCode,
            dayCountryName: day.countryName,
            calendarCount: day.calendarCount,
            sources: day.sources
        )

        XCTAssertEqual(resolved.map(\.eventIdentifier), ["flight-1"])
    }

    func testResolveFallsBackToAdjacentRegularCalendarSignalsWhenOriginSignalIsUnavailable() {
        let day = makePresenceDay(
            dayKey: "2026-03-16",
            date: Date(timeIntervalSince1970: 1_000),
            timeZoneId: "America/Los_Angeles",
            countryCode: "US",
            countryName: "United States",
            confidence: 0.5,
            confidenceLabel: .medium,
            sources: .calendar,
            isOverride: false,
            stayCount: 0,
            photoCount: 0,
            locationCount: 0,
            calendarCount: 1
        )

        let adjacentSignals = [
            CalendarSignal(
                timestamp: Date(timeIntervalSince1970: 2_000),
                dayKey: "2026-03-15",
                latitude: 37.6213,
                longitude: -122.3790,
                countryCode: "US",
                countryName: "United States",
                timeZoneId: "America/Los_Angeles",
                eventIdentifier: "flight-2",
                title: "Arrive in San Francisco",
                source: "Calendar"
            ),
            CalendarSignal(
                timestamp: Date(timeIntervalSince1970: 3_000),
                dayKey: "2026-03-15",
                latitude: 51.4700,
                longitude: -0.4543,
                countryCode: "GB",
                countryName: "United Kingdom",
                timeZoneId: "Europe/London",
                eventIdentifier: "meeting-1",
                title: "Airport transfer",
                source: "Calendar"
            )
        ]

        let resolved = CalendarEvidenceResolver.resolve(
            sameDaySignals: [],
            adjacentSignals: adjacentSignals,
            dayCountryCode: day.countryCode,
            dayCountryName: day.countryName,
            calendarCount: day.calendarCount,
            sources: day.sources
        )

        XCTAssertEqual(resolved.map(\.eventIdentifier), ["flight-2"])
    }
}
#endif
