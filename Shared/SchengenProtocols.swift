//
//  SchengenProtocols.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import Foundation

protocol SchengenStay {
    var enteredOn: Date { get }
    var exitedOn: Date? { get }
    var region: Region { get }
}

protocol SchengenOverride {
    var date: Date { get }
    var region: Region { get }
}

struct StayInfo: SchengenStay, Sendable {
    let enteredOn: Date
    let exitedOn: Date?
    let region: Region
    let entryDayKey: String?
    let exitDayKey: String?

    init(
        enteredOn: Date,
        exitedOn: Date?,
        region: Region,
        entryDayKey: String? = nil,
        exitDayKey: String? = nil
    ) {
        self.enteredOn = enteredOn
        self.exitedOn = exitedOn
        self.region = region
        self.entryDayKey = entryDayKey
        self.exitDayKey = exitDayKey
    }
}

struct OverrideInfo: SchengenOverride, Sendable {
    let date: Date
    let region: Region
    let dayKey: String?

    init(date: Date, region: Region, dayKey: String? = nil) {
        self.date = date
        self.region = region
        self.dayKey = dayKey
    }
}
