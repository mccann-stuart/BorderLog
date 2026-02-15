
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

    @Test func overlapCountDetectsOverlaps() {
        // Overlap:
        // Stay 1: Jan 1 - Jan 5
        // Stay 2: Jan 4 - Jan 8 (overlap)
        // Stay 3: Jan 7 - Jan 10 (overlap with Stay 2, but if logic is flawed, might be missed)

        // Wait, let's trace the logic again.
        // Stay 1: [1, 5] -> currentEnd = 5
        // Stay 2: [4, 8] -> 4 <= 5 -> Overlap! currentEnd should be max(5, 8) = 8.
        // Stay 3: [7, 10] -> 7 <= 8 -> Overlap!

        // If the bug exists (shadowing prevents update):
        // Stay 1: [1, 5] -> currentEnd = 5
        // Stay 2: [4, 8] -> 4 <= 5 -> Overlap! but currentEnd update fails (remains 5).
        // Stay 3: [7, 10] -> 7 > 5 -> No overlap detected.

        // So with bug: 1 overlap detected (Stay 2).
        // Without bug: 2 overlaps detected (Stay 2 and Stay 3).

        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 4), exitedOn: date(2026, 1, 8))
        let stay3 = Stay(countryName: "C", region: .schengen, enteredOn: date(2026, 1, 7), exitedOn: date(2026, 1, 10))

        // Note: The function expects reverse sorted input (descending by enteredOn),
        // because it reverses it internally to get ascending.
        // So we should pass [stay3, stay2, stay1] if we want them processed in order 1 -> 2 -> 3.
        // Actually, let's verify the comment in the code:
        // "Optimization: Input is typically reverse-sorted by 'enteredOn' from the query.
        // Reversing provides ascending order in O(1) without additional allocation."
        // So if I pass [stay3, stay2, stay1], it reverses to [stay1, stay2, stay3].

        let stays = [stay3, stay2, stay1]

        let count = StayValidation.overlapCount(stays: stays, calendar: calendar)

        // With correct logic: 2 overlaps.
        // With buggy logic: 1 overlap.
        #expect(count == 2)
    }

    @Test func overlappingStaysDetectsConflicts() {
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

        #expect(overlaps.count == 2)
        #expect(overlaps.contains(where: { $0.countryName == "A" }))
        #expect(overlaps.contains(where: { $0.countryName == "B" }))

        // No overlap (Jan 11-15)
        let noOverlaps = StayValidation.overlappingStays(
            enteredOn: date(2026, 1, 11),
            exitedOn: date(2026, 1, 15),
            stays: stays,
            excluding: nil,
            calendar: calendar
        )

        #expect(noOverlaps.isEmpty)
    }

    @Test func overlappingStaysExcludesCurrentStay() {
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

        #expect(overlaps.isEmpty)
    }

    @Test func overlappingStaysHandlesOpenEndedStays() {
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

        #expect(overlaps.count == 1)
        #expect(overlaps.first?.countryName == "C")

        // Overlaps when input is open ended (Jan 18 - Future)
        let openInputOverlaps = StayValidation.overlappingStays(
            enteredOn: date(2026, 1, 18),
            exitedOn: nil,
            stays: stays,
            excluding: nil,
            calendar: calendar
        )

        #expect(openInputOverlaps.count == 1)
        #expect(openInputOverlaps.first?.countryName == "C")
    }

    @Test func overlappingStaysHandlesTouchingDates() {
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

        #expect(overlaps.count == 2)
        #expect(overlaps.contains(where: { $0.countryName == "A" }))
        #expect(overlaps.contains(where: { $0.countryName == "B" }))
    @Test func gapDaysCalculatesCorrectly() {
        // 1. Simple gap (2 days gap: Jan 5 to Jan 7 -> gap is Jan 6, 1 day)
        // Stay 1: Jan 1 - Jan 5
        // Stay 2: Jan 7 - Jan 10
        // Gap: Jan 6 (1 day)
        let stay1 = Stay(countryName: "A", region: .schengen, enteredOn: date(2026, 1, 1), exitedOn: date(2026, 1, 5))
        let stay2 = Stay(countryName: "B", region: .schengen, enteredOn: date(2026, 1, 7), exitedOn: date(2026, 1, 10))
        #expect(StayValidation.gapDays(stays: [stay1, stay2], calendar: calendar) == 1)

        // 2. No gap (consecutive: Jan 5 to Jan 6)
        // Stay 3: Jan 6 - Jan 10
        let stay3 = Stay(countryName: "C", region: .schengen, enteredOn: date(2026, 1, 6), exitedOn: date(2026, 1, 10))
        #expect(StayValidation.gapDays(stays: [stay1, stay3], calendar: calendar) == 0)

        // 3. Overlap (Jan 4 start, before Jan 5 end) - should be 0 gap
        // Stay 4: Jan 4 - Jan 8
        let stay4 = Stay(countryName: "D", region: .schengen, enteredOn: date(2026, 1, 4), exitedOn: date(2026, 1, 8))
        #expect(StayValidation.gapDays(stays: [stay1, stay4], calendar: calendar) == 0)

        // 4. Multiple gaps
        // Stay 1: 1-5
        // Stay 2: 7-10 (gap: 6, size 1)
        // Stay 5: 15-20 (gap: 11-14, size 4)
        // Total gap: 1 + 4 = 5
        let stay5 = Stay(countryName: "E", region: .schengen, enteredOn: date(2026, 1, 15), exitedOn: date(2026, 1, 20))
        #expect(StayValidation.gapDays(stays: [stay1, stay2, stay5], calendar: calendar) == 5)

        // 5. Unsorted input (Stay 2 before Stay 1 in list)
        // Should sort to [stay1, stay2] and calculate gap 1.
        #expect(StayValidation.gapDays(stays: [stay2, stay1], calendar: calendar) == 1)

        // 6. Single stay
        #expect(StayValidation.gapDays(stays: [stay1], calendar: calendar) == 0)

        // 7. Empty list
        #expect(StayValidation.gapDays(stays: [], calendar: calendar) == 0)
    }
}
