
import Testing
import Foundation
import SwiftData
@testable import Learn

struct StayValidationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func overlapCount_EmptyStays_ReturnsZero() {
        let count = StayValidation.overlapCount(stays: [], calendar: calendar)
        #expect(count == 0)
    }

    @Test func overlapCount_SingleStay_ReturnsZero() {
        let stay = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let count = StayValidation.overlapCount(stays: [stay], calendar: calendar)
        #expect(count == 0)
    }

    @Test func overlapCount_DisjointStays_ReturnsZero() {
        // Stay 1: 1-5
        // Stay 2: 6-10
        // Ensures disjoint intervals are not counted as overlaps even if processed out of order.
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 6), exitedOn: date(2026, 1, 10))

        // Pass in ascending order to test robustness against input order assumptions.
        let count = StayValidation.overlapCount(stays: [stay1, stay2], calendar: calendar)
        #expect(count == 0)
    }

    @Test func overlapCount_SimpleOverlap_ReturnsCount() {
        // Stay 1: 1-5
        // Stay 2: 4-8
        // Overlap: 4-5
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 4), exitedOn: date(2026, 1, 8))

        let count = StayValidation.overlapCount(stays: [stay2, stay1], calendar: calendar)
        #expect(count == 1)
    }

    @Test func overlapCount_NestedOverlap_ReturnsCount() {
        // Stay 1: 1-10
        // Stay 2: 3-6 (Inside Stay 1)
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 10))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 3), exitedOn: date(2026, 1, 6))

        let count = StayValidation.overlapCount(stays: [stay2, stay1], calendar: calendar)
        #expect(count == 1)
    }

    @Test func overlapCount_TouchingStays_ReturnsCount() {
        // Stay 1: 1-5
        // Stay 2: 5-10
        // Touching on day 5 counts as overlap.
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 5), exitedOn: date(2026, 1, 10))

        let count = StayValidation.overlapCount(stays: [stay2, stay1], calendar: calendar)
        #expect(count == 1)
    }

    @Test func overlapCount_UnsortedInput_DetectsOverlapsCorrectly() {
        // Stay 1: 1-5
        // Stay 2: 4-8
        // Stay 3: 7-10

        // Overlap 1: Stay 1 & Stay 2 (4-5)
        // Overlap 2: Stay 2 & Stay 3 (7-8)
        // Stay 1 & Stay 3 do not overlap.
        // Total overlaps: 2

        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 4), exitedOn: date(2026, 1, 8))
        let stay3 = Stay(countryName: "C", region: .schengen, enteredOn: date(2026, 1, 7), exitedOn: date(2026, 1, 10))

        // Pass in unsorted/mixed order
        let count = StayValidation.overlapCount(stays: [stay2, stay3, stay1], calendar: calendar)
        #expect(count == 2)
    }

    @Test func overlapCount_AscendingInput_DetectsOverlapsCorrectly() {
        // Same as above, but explicitly sorted ascending input.
        // Ensures logic does not rely on descending sort assumption.

        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 4), exitedOn: date(2026, 1, 8))
        let stay3 = Stay(countryName: "C", region: .schengen, enteredOn: date(2026, 1, 7), exitedOn: date(2026, 1, 10))

        let count = StayValidation.overlapCount(stays: [stay1, stay2, stay3], calendar: calendar)
        #expect(count == 2)
    }
}
