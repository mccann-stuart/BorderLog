
import XCTest
import Foundation
import SwiftData
@testable import Learn
final class StayValidationTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testOverlapCount_EmptyStays_ReturnsZero() {
        let count = StayValidation.overlapCount(stays: [Stay](), calendar: calendar)
        XCTAssertTrue(count == 0)
    }

    func testOverlapCount_SingleStay_ReturnsZero() {
        let stay = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let count = StayValidation.overlapCount(stays: [stay], calendar: calendar)
        XCTAssertTrue(count == 0)
    }

    func testOverlapCount_DisjointStays_ReturnsZero() {
        // Stay 1: 1-5
        // Stay 2: 6-10
        // Ensures disjoint intervals are not counted as overlaps even if processed out of order.
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 6), exitedOn: date(2026, 1, 10))

        // Pass in ascending order to test robustness against input order assumptions.
        let count = StayValidation.overlapCount(stays: [stay1, stay2], calendar: calendar)
        XCTAssertTrue(count == 0)
    }

    func testOverlapCount_SimpleOverlap_ReturnsCount() {
        // Stay 1: 1-5
        // Stay 2: 4-8
        // Overlap: 4-5
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 4), exitedOn: date(2026, 1, 8))

        let count = StayValidation.overlapCount(stays: [stay2, stay1], calendar: calendar)
        XCTAssertTrue(count == 1)
    }

    func testOverlapCount_NestedOverlap_ReturnsCount() {
        // Stay 1: 1-10
        // Stay 2: 3-6 (Inside Stay 1)
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 10))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 3), exitedOn: date(2026, 1, 6))

        let count = StayValidation.overlapCount(stays: [stay2, stay1], calendar: calendar)
        XCTAssertTrue(count == 1)
    }

    func testOverlapCount_TouchingStays_ReturnsCount() {
        // Stay 1: 1-5
        // Stay 2: 5-10
        // Touching on day 5 counts as overlap.
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 5), exitedOn: date(2026, 1, 10))

        let count = StayValidation.overlapCount(stays: [stay2, stay1], calendar: calendar)
        XCTAssertTrue(count == 1)
    }

    func testOverlapCount_UnsortedInput_DetectsOverlapsCorrectly() {
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
        XCTAssertTrue(count == 2)
    }

    func testOverlapCount_AscendingInput_DetectsOverlapsCorrectly() {
        // Same as above, but explicitly sorted ascending input.
        // Ensures logic does not rely on descending sort assumption.

        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 4), exitedOn: date(2026, 1, 8))
        let stay3 = Stay(countryName: "C", region: .schengen, enteredOn: date(2026, 1, 7), exitedOn: date(2026, 1, 10))

        let count = StayValidation.overlapCount(stays: [stay1, stay2, stay3], calendar: calendar)
        XCTAssertTrue(count == 2)
    }

    func testOverlappingStaysDetectsConflicts() {
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 6), exitedOn: date(2026, 1, 10))
        let stays = [stay1, stay2]

        // Overlaps with stay1 (Jan 4-5) and stay2 (Jan 6-8)
        let overlaps = StayValidation.overlappingStays(
            enteredOn: date(2026, 1, 4),
            exitedOn: date(2026, 1, 8),
            stays: stays,
            excluding: nil,
            calendar: calendar
        )

        XCTAssertTrue(overlaps.count == 2)
        XCTAssertTrue(overlaps.contains(where: { $0.countryName == "A" }))
        XCTAssertTrue(overlaps.contains(where: { $0.countryName == "B" }))

        // No overlap (Jan 11-15)
        let noOverlaps = StayValidation.overlappingStays(
            enteredOn: date(2026, 1, 11),
            exitedOn: date(2026, 1, 15),
            stays: stays,
            excluding: nil,
            calendar: calendar
        )

        XCTAssertTrue(noOverlaps.isEmpty)
    }

    func testOverlappingStaysExcludesCurrentStay() {
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 6), exitedOn: date(2026, 1, 10))
        let stays = [stay1, stay2]

        // Overlaps with stay1, but we exclude it (simulating edit)
        let overlaps = StayValidation.overlappingStays(
            enteredOn: date(2026, 1, 2),
            exitedOn: date(2026, 1, 4),
            stays: stays,
            excluding: stay1,
            calendar: calendar
        )

        XCTAssertTrue(overlaps.isEmpty)
    }

    func testOverlappingStaysHandlesOpenEndedStays() {
        // Open ended stay starts Jan 15
        let stay3 = Stay(countryName: "C", region: .schengen, enteredOn: date(2026, 1, 15), exitedOn: nil)
        let stays = [stay3]

        // Overlaps with open ended stay (Jan 20-25)
        let overlaps = StayValidation.overlappingStays(
            enteredOn: date(2026, 1, 20),
            exitedOn: date(2026, 1, 25),
            stays: stays,
            excluding: nil,
            calendar: calendar
        )

        XCTAssertTrue(overlaps.count == 1)
        XCTAssertTrue(overlaps.first?.countryName == "C")

        // Overlaps when input is open ended (Jan 18 - Future)
        let openInputOverlaps = StayValidation.overlappingStays(
            enteredOn: date(2026, 1, 18),
            exitedOn: nil,
            stays: stays,
            excluding: nil,
            calendar: calendar
        )

        XCTAssertTrue(openInputOverlaps.count == 1)
        XCTAssertTrue(openInputOverlaps.first?.countryName == "C")
    }

    func testOverlappingStaysHandlesTouchingDates() {
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 6), exitedOn: date(2026, 1, 10))
        let stays = [stay1, stay2]

        // Touching dates (Jan 5-6)
        // Should overlap with stay1 (ends Jan 5) and stay2 (starts Jan 6)
        // because ranges are inclusive [start, end]
        let overlaps = StayValidation.overlappingStays(
            enteredOn: date(2026, 1, 5),
            exitedOn: date(2026, 1, 6),
            stays: stays,
            excluding: nil,
            calendar: calendar
        )

        XCTAssertTrue(overlaps.count == 2)
        XCTAssertTrue(overlaps.contains(where: { $0.countryName == "A" }))
        XCTAssertTrue(overlaps.contains(where: { $0.countryName == "B" }))
    }

    func testGapDaysCalculatesCorrectly() {
        // 1. Simple gap (2 days gap: Jan 5 to Jan 7 -> gap is Jan 6, 1 day)
        // Stay 1: Jan 1 - Jan 5
        // Stay 2: Jan 7 - Jan 10
        // Gap: Jan 6 (1 day)
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 7), exitedOn: date(2026, 1, 10))
        XCTAssertTrue(StayValidation.gapDays(stays: [stay1, stay2], calendar: calendar) == 1)

        // 2. No gap (consecutive: Jan 5 to Jan 6)
        // Stay 3: Jan 6 - Jan 10
        let stay3 = Stay(countryName: "C", region: .schengen, enteredOn: date(2026, 1, 6), exitedOn: date(2026, 1, 10))
        XCTAssertTrue(StayValidation.gapDays(stays: [stay1, stay3], calendar: calendar) == 0)

        // 3. Overlap (Jan 4 start, before Jan 5 end) - should be 0 gap
        // Stay 4: Jan 4 - Jan 8
        let stay4 = Stay(countryName: "D", region: .schengen, enteredOn: date(2026, 1, 4), exitedOn: date(2026, 1, 8))
        XCTAssertTrue(StayValidation.gapDays(stays: [stay1, stay4], calendar: calendar) == 0)

        // 4. Multiple gaps
        // Stay 1: 1-5
        // Stay 2: 7-10 (gap: 6, size 1)
        // Stay 5: 15-20 (gap: 11-14, size 4)
        // Total gap: 1 + 4 = 5
        let stay5 = Stay(countryName: "E", region: .schengen, enteredOn: date(2026, 1, 15), exitedOn: date(2026, 1, 20))
        XCTAssertTrue(StayValidation.gapDays(stays: [stay1, stay2, stay5], calendar: calendar) == 5)

        // 5. Unsorted input (Stay 2 before Stay 1 in list)
        // Should sort to [stay1, stay2] and calculate gap 1.
        XCTAssertTrue(StayValidation.gapDays(stays: [stay2, stay1], calendar: calendar) == 1)

        // 6. Single stay
        XCTAssertTrue(StayValidation.gapDays(stays: [stay1], calendar: calendar) == 0)

        // 7. Empty list
        XCTAssertTrue(StayValidation.gapDays(stays: [Stay](), calendar: calendar) == 0)
    }

    func testOverlapCount_Optimized_WithReverseSortedInput_ReturnsCount() {
        // Optimized variant requires reverse sorted input (descending)
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 4), exitedOn: date(2026, 1, 8))
        let stay3 = Stay(countryName: "C", region: .schengen, enteredOn: date(2026, 1, 7), exitedOn: date(2026, 1, 10))

        // Input: [stay3, stay2, stay1] (Descending)
        let count = StayValidation.overlapCount(reverseSortedStays: [stay3, stay2, stay1], calendar: calendar)
        XCTAssertTrue(count == 2)

        // Disjoint reverse sorted
        let countDisjoint = StayValidation.overlapCount(reverseSortedStays: [stay2, stay1], calendar: calendar)
        // stay2 (Jan 4-8), stay1 (Jan 1-5) -> Overlap Jan 4-5.
        // Wait, Disjoint test used stay1 (1-5) and stay2 (6-10).
        let stayA = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stayB = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 6), exitedOn: date(2026, 1, 10))
        let countDisjoint2 = StayValidation.overlapCount(reverseSortedStays: [stayB, stayA], calendar: calendar)
        XCTAssertTrue(countDisjoint2 == 0)
    }

    func testGapDays_Optimized_WithReverseSortedInput_CalculatesCorrectly() {
        // 1. Simple gap
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 7), exitedOn: date(2026, 1, 10))
        // Reverse sorted: [stay2, stay1]
        XCTAssertTrue(StayValidation.gapDays(reverseSortedStays: [stay2, stay1], calendar: calendar) == 1)

        // 2. No gap (consecutive)
        let stay3 = Stay(countryName: "C", region: .schengen, enteredOn: date(2026, 1, 6), exitedOn: date(2026, 1, 10))
        XCTAssertTrue(StayValidation.gapDays(reverseSortedStays: [stay3, stay1], calendar: calendar) == 0)
    }

    func testGapDays_WithOpenEndedStay_CalculatesCorrectly() {
        // Stay 1: Jan 1 - Jan 5
        // Stay 2: Jan 10 - Ongoing
        // Stay 3: Jan 20 - Jan 25

        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 10), exitedOn: nil)
        let stay3 = Stay(countryName: "C", region: .schengen, enteredOn: date(2026, 1, 20), exitedOn: date(2026, 1, 25))

        // Expected gaps:
        // Jan 5 to Jan 10 -> 4 days gap.
        // Jan 10 to Jan 20 -> User is present (ongoing). No gap.
        // Total: 4.

        // Pass sorted input for standard function
        XCTAssertTrue(StayValidation.gapDays(stays: [stay1, stay2, stay3], calendar: calendar) == 4)

        // Pass reverse sorted input for optimized function
        XCTAssertTrue(StayValidation.gapDays(reverseSortedStays: [stay3, stay2, stay1], calendar: calendar) == 4)
    }
}
