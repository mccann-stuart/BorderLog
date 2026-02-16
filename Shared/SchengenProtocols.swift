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
}

struct OverrideInfo: SchengenOverride, Sendable {
    let date: Date
    let region: Region
}
