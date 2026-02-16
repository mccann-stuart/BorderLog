//
//  SignalTypes.swift
//  Learn
//
//  Created by Mccann Stuart on 16/02/2026.
//

import Foundation

enum ConfidenceLabel: String, CaseIterable, Codable {
    case high
    case medium
    case low
}

struct SignalSourceMask: OptionSet, Codable, Sendable {
    let rawValue: Int

    static let override = SignalSourceMask(rawValue: 1 << 0)
    static let stay = SignalSourceMask(rawValue: 1 << 1)
    static let photo = SignalSourceMask(rawValue: 1 << 2)
    static let location = SignalSourceMask(rawValue: 1 << 3)

    static let none: SignalSourceMask = []
    static let all: SignalSourceMask = [.override, .stay, .photo, .location]
}

struct LocationSignalInfo: Sendable {
    let dayKey: String
    let countryCode: String
    let countryName: String
    let accuracyMeters: Double
    let timeZoneId: String?
}

struct PhotoSignalInfo: Sendable {
    let dayKey: String
    let countryCode: String
    let countryName: String
    let timeZoneId: String?
}

struct StayPresenceInfo: Sendable {
    let enteredOn: Date
    let exitedOn: Date?
    let countryCode: String?
    let countryName: String
}

struct OverridePresenceInfo: Sendable {
    let date: Date
    let countryCode: String?
    let countryName: String
}

struct PresenceDayResult: Sendable {
    let dayKey: String
    let date: Date
    let timeZoneId: String?
    let countryCode: String?
    let countryName: String?
    let confidence: Double
    let confidenceLabel: ConfidenceLabel
    let sources: SignalSourceMask
    let isOverride: Bool
    let stayCount: Int
    let photoCount: Int
    let locationCount: Int
}
