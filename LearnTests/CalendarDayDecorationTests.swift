#if canImport(XCTest)
import XCTest
@testable import Learn

final class CalendarDayDecorationTests: XCTestCase {
    private func country(_ code: String) -> CalendarDayCountry {
        CalendarDayCountry(
            id: code,
            countryName: Locale.autoupdatingCurrent.localizedString(forRegionCode: code) ?? code,
            countryCode: code,
            regionRaw: SchengenMembers.isMember(code) ? Region.schengen.rawValue : Region.nonSchengen.rawValue
        )
    }

    private func summary(
        countries: [CalendarDayCountry],
        flightOriginCountry: CalendarDayCountry? = nil,
        flightDestinationCountry: CalendarDayCountry? = nil,
        hasFlight: Bool
    ) -> CalendarDaySummary {
        CalendarDaySummary(
            dayKey: "2026-03-15",
            date: Date(timeIntervalSince1970: 1_000),
            dayNumber: 15,
            countries: countries,
            flightOriginCountry: flightOriginCountry,
            flightDestinationCountry: flightDestinationCountry,
            hasFlight: hasFlight,
            isToday: false,
            isInCurrentMonth: true
        )
    }

    func testCalendarDayDecorationTokensRenderOriginPlaneDestination() {
        let origin = country("GB")
        let destination = country("US")

        let tokens = calendarDayDecorationTokens(
            for: summary(
                countries: [origin, destination],
                flightOriginCountry: origin,
                flightDestinationCountry: destination,
                hasFlight: true
            )
        )

        XCTAssertEqual(tokens, ["🇬🇧", "✈️", "🇺🇸"])
    }

    func testCalendarDayDecorationTokensRenderOriginOnlyFlight() {
        let origin = country("GB")
        let extra = country("ES")

        let tokens = calendarDayDecorationTokens(
            for: summary(
                countries: [origin, extra],
                flightOriginCountry: origin,
                flightDestinationCountry: nil,
                hasFlight: true
            )
        )

        XCTAssertEqual(tokens, ["🇬🇧", "✈️", "🇪🇸"])
    }

    func testCalendarDayDecorationTokensRenderDestinationOnlyFlight() {
        let destination = country("US")
        let extra = country("CA")

        let tokens = calendarDayDecorationTokens(
            for: summary(
                countries: [destination, extra],
                flightOriginCountry: nil,
                flightDestinationCountry: destination,
                hasFlight: true
            )
        )

        XCTAssertEqual(tokens, ["✈️", "🇺🇸", "🇨🇦"])
    }

    func testCalendarDayDecorationTokensAppendExtrasWithoutDuplicates() {
        let origin = country("GB")
        let destination = country("US")
        let canada = country("CA")
        let mexico = country("MX")

        let tokens = calendarDayDecorationTokens(
            for: summary(
                countries: [origin, destination, canada, mexico],
                flightOriginCountry: origin,
                flightDestinationCountry: destination,
                hasFlight: true
            )
        )

        XCTAssertEqual(tokens, ["🇬🇧", "✈️", "🇺🇸", "🇨🇦", "🇲🇽"])
    }
}
#endif
