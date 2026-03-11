import XCTest
@testable import Learn

final class CalendarFlightParsingTests: XCTestCase {
    private func snapshot(
        title: String?,
        location: String? = nil,
        structuredLocationTitle: String? = nil,
        notes: String? = nil
    ) -> CalendarEventTextSnapshot {
        CalendarEventTextSnapshot(
            title: title,
            location: location,
            structuredLocationTitle: structuredLocationTitle,
            notes: notes
        )
    }

    func testShouldIngestRejectsFriendTaggedEvents() {
        XCTAssertFalse(CalendarFlightParsing.shouldIngest(event: snapshot(title: "Flight to Paris", notes: "Friend: Alice")))
    }

    func testShouldIngestAcceptsFlightKeywordsOrEmoji() {
        let keywordSnapshot = snapshot(title: "Flight to Paris")
        XCTAssertTrue(CalendarFlightParsing.shouldIngest(event: keywordSnapshot))

        let emojiSnapshot = snapshot(title: "LHR ✈ JFK")
        XCTAssertTrue(CalendarFlightParsing.shouldIngest(event: emojiSnapshot))
    }

    func testParseFlightInfoFromAirportCodes() {
        let parsed = CalendarFlightParsing.parseFlightInfo(event: snapshot(title: "LHR - JFK"))
        XCTAssertEqual(parsed.from, "LHR")
        XCTAssertEqual(parsed.to, "JFK")
    }

    func testParseFlightInfoFromTextPatterns() {
        let fromTo = CalendarFlightParsing.parseFlightInfo(event: snapshot(title: "From Madrid to Paris"))
        XCTAssertEqual(fromTo.from, "Madrid")
        XCTAssertEqual(fromTo.to, "Paris")

        let plane = CalendarFlightParsing.parseFlightInfo(event: snapshot(title: "Lisbon ✈ Rome"))
        XCTAssertEqual(plane.from, "Lisbon")
        XCTAssertEqual(plane.to, "Rome")
    }

    func testParseFlightInfoReturnsDestinationWhenOnlyToPatternExists() {
        let parsed = CalendarFlightParsing.parseFlightInfo(event: snapshot(title: "Work travel", notes: "Flight to Berlin"))
        XCTAssertNil(parsed.from)
        XCTAssertEqual(parsed.to, "Berlin")
    }

    func testParseFlightInfoCleansDestinationFlightSuffix() {
        let parsed = CalendarFlightParsing.parseFlightInfo(event: snapshot(title: "Flight to Munich (LH 4087)"))
        XCTAssertNil(parsed.from)
        XCTAssertEqual(parsed.to, "Munich")
    }

    func testParseFlightInfoFromFlightNumberRoute() {
        let parsed = CalendarFlightParsing.parseFlightInfo(
            event: snapshot(title: "MCCANN_STUART - Flight LH4087 Manchester to Munich Tue 10 Mar 2026 17:40/20:40")
        )
        XCTAssertEqual(parsed.from, "Manchester")
        XCTAssertEqual(parsed.to, "Munich")
    }

    func testParseFlightInfoCleansTrailingPunctuation() {
        let parsed = CalendarFlightParsing.parseFlightInfo(event: snapshot(title: "Flight LH4087 Manchester to Munich."))
        XCTAssertEqual(parsed.from, "Manchester")
        XCTAssertEqual(parsed.to, "Munich")
    }

    func testParseFlightInfoFromExplicitRoute() {
        let parsed = CalendarFlightParsing.parseFlightInfo(event: snapshot(title: "Flight: LH 4087 from MAN to MUC"))
        XCTAssertEqual(parsed.from, "MAN")
        XCTAssertEqual(parsed.to, "MUC")
    }
}
