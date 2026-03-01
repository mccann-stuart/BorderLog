import XCTest
@testable import Learn

final class CalendarFlightParsingTests: XCTestCase {
    func testShouldIngestRejectsFriendTaggedEvents() {
        let snapshot = CalendarEventTextSnapshot(
            title: "Flight to Paris",
            location: nil,
            structuredLocationTitle: nil,
            notes: "Friend: Alice"
        )
        XCTAssertFalse(CalendarFlightParsing.shouldIngest(event: snapshot))
    }

    func testShouldIngestAcceptsFlightKeywordsOrEmoji() {
        let keywordSnapshot = CalendarEventTextSnapshot(
            title: "Flight to Paris",
            location: nil,
            structuredLocationTitle: nil,
            notes: nil
        )
        XCTAssertTrue(CalendarFlightParsing.shouldIngest(event: keywordSnapshot))

        let emojiSnapshot = CalendarEventTextSnapshot(
            title: "LHR ✈ JFK",
            location: nil,
            structuredLocationTitle: nil,
            notes: nil
        )
        XCTAssertTrue(CalendarFlightParsing.shouldIngest(event: emojiSnapshot))
    }

    func testParseFlightInfoFromAirportCodes() {
        let parsed = CalendarFlightParsing.parseFlightInfo(title: "LHR - JFK", notes: nil)
        XCTAssertEqual(parsed.from, "LHR")
        XCTAssertEqual(parsed.to, "JFK")
    }

    func testParseFlightInfoFromTextPatterns() {
        let fromTo = CalendarFlightParsing.parseFlightInfo(title: "From Madrid to Paris", notes: nil)
        XCTAssertEqual(fromTo.from, "Madrid")
        XCTAssertEqual(fromTo.to, "Paris")

        let plane = CalendarFlightParsing.parseFlightInfo(title: "Lisbon ✈ Rome", notes: nil)
        XCTAssertEqual(plane.from, "Lisbon")
        XCTAssertEqual(plane.to, "Rome")
    }

    func testParseFlightInfoReturnsDestinationWhenOnlyToPatternExists() {
        let parsed = CalendarFlightParsing.parseFlightInfo(title: "Work travel", notes: "Flight to Berlin")
        XCTAssertNil(parsed.from)
        XCTAssertEqual(parsed.to, "Berlin")
    }
}
