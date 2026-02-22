//
//  SchengenStateTests.swift
//  LearnTests
//
//  Created by Jules on 16/02/2026.
//

import XCTest
import Foundation
import SwiftData
@testable import Learn

@MainActor
final class SchengenStateTests: XCTestCase {

    // Helper to create dates relative to today using the current calendar
    // to match SchengenState's internal usage of Calendar.current.
    private func dateAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    }

    func testUpdate_calculatesSummaryCorrectly() async {
        let state = SchengenState()

        // Stay: 10 days ago to 5 days ago (inclusive)
        // Duration: 6 days
        let enteredOn = dateAgo(10)
        let exitedOn = dateAgo(5)

        let stay = Stay(
            countryName: "France",
            countryCode: "FR",
            region: .schengen,
            enteredOn: enteredOn,
            exitedOn: exitedOn
        )

        // Pass stays sorted descending by enteredOn
        await state.update(stays: [stay], overrides: [])

        XCTAssertEqual(state.summary.usedDays, 6)
        XCTAssertEqual(state.overlapCount, 0)
        XCTAssertEqual(state.gapDays, 0)
    }

    func testUpdate_handlesEmptyData() async {
        let state = SchengenState()
        await state.update(stays: [], overrides: [])

        XCTAssertEqual(state.summary.usedDays, 0)
        XCTAssertEqual(state.summary.remainingDays, 90)
        XCTAssertEqual(state.overlapCount, 0)
        XCTAssertEqual(state.gapDays, 0)
    }

    func testUpdate_handlesOverrides() async {
        let state = SchengenState()

        // Stay: 10 days ago to 1 day ago (10 days total)
        let enteredOn = dateAgo(10)
        let exitedOn = dateAgo(1)

        let stay = Stay(
            countryName: "Germany",
            countryCode: "DE",
            region: .schengen,
            enteredOn: enteredOn,
            exitedOn: exitedOn
        )

        // Override: 5 days ago -> Non-Schengen (removes 1 day from count)
        let overrideDate = dateAgo(5)
        let override = DayOverride(
            date: overrideDate,
            countryName: "United Kingdom",
            countryCode: "GB",
            region: .nonSchengen
        )

        await state.update(stays: [stay], overrides: [override])

        XCTAssertEqual(state.summary.usedDays, 9) // 10 - 1
        XCTAssertEqual(state.summary.remainingDays, 81) // 90 - 9
    }

    func testUpdate_detectsOverlapsAndGaps() async {
        let state = SchengenState()

        // Stay 1: 10 days ago to 5 days ago
        let stay1 = Stay(
            countryName: "A",
            region: .schengen,
            enteredOn: dateAgo(10),
            exitedOn: dateAgo(5)
        )

        // Stay 2: 7 days ago to 2 days ago
        // Overlaps with Stay 1 (days -7, -6, -5)
        let stay2 = Stay(
            countryName: "B",
            region: .schengen,
            enteredOn: dateAgo(7),
            exitedOn: dateAgo(2)
        )

        // Stay 3: 20 days ago to 15 days ago
        // Gap between Stay 3 (ends -15) and Stay 1 (starts -10)
        // Gap is -14, -13, -12, -11 (4 days)
        let stay3 = Stay(
            countryName: "C",
            region: .schengen,
            enteredOn: dateAgo(20),
            exitedOn: dateAgo(15)
        )

        // Sorted descending by enteredOn: Stay 2 (-7), Stay 1 (-10), Stay 3 (-20)
        let stays = [stay2, stay1, stay3]

        await state.update(stays: stays, overrides: [])

        XCTAssertEqual(state.overlapCount, 1)
        XCTAssertEqual(state.gapDays, 4)
    }
}
