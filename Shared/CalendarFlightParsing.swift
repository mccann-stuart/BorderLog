//
//  CalendarFlightParsing.swift
//  Learn
//
//  Created by Codex on 01/03/2026.
//

import Foundation

struct CalendarEventTextSnapshot: Sendable {
    let title: String?
    let location: String?
    let structuredLocationTitle: String?
    let notes: String?
}

enum CalendarEventIngestability: Sendable {
    case flight
    case otherTravelOrLodging
    case none

    nonisolated var shouldIngest: Bool {
        switch self {
        case .none:
            return false
        case .flight, .otherTravelOrLodging:
            return true
        }
    }

    nonisolated var shouldDecorateAsFlight: Bool {
        switch self {
        case .flight:
            return true
        case .otherTravelOrLodging, .none:
            return false
        }
    }
}

enum CalendarFlightParsing {

    // MARK: - Regex Patterns

    private nonisolated static let patternFromTo = try! NSRegularExpression(pattern: "(?:from\\s+(.+?)\\s+to\\s+(.+))", options: [.caseInsensitive])
    private nonisolated static let patternTo = try! NSRegularExpression(pattern: "(?:flight|train|ferry|bus)\\s+to\\s+(.+)", options: [.caseInsensitive])
    private nonisolated static let patternHotel = try! NSRegularExpression(pattern: "hotel\\s+(?:in|at)\\s+(.+)", options: [.caseInsensitive])
    private nonisolated static let patternFlightNumberRoute = try! NSRegularExpression(
        pattern: "flight\\s*[:\\-]?\\s*[A-Z]{1,3}\\s*\\d{1,4}\\s+(.+?)\\s+to\\s+(.+)",
        options: [.caseInsensitive]
    )
    private nonisolated static let patternLineRoute = try! NSRegularExpression(
        pattern: "^\\s*([\\p{L}][\\p{L}\\p{M} .'-]{1,80}?)\\s+to\\s+([\\p{L}][\\p{L}\\p{M} .'-]{1,80}?)\\s*$",
        options: [.caseInsensitive, .anchorsMatchLines]
    )
    private nonisolated static let patternPlane = try! NSRegularExpression(pattern: "(.+?)\\s*✈\\s*(.+)", options: [])
    private nonisolated static let patternPlaneEmoji = try! NSRegularExpression(pattern: "(.+?)\\s*✈️\\s*(.+)", options: [])
    private nonisolated static let patternCodes = try! NSRegularExpression(pattern: "\\b([A-Z]{3})\\s*(?:[-/→]|->)\\s*([A-Z]{3})\\b", options: [])

    private nonisolated static let patternWhitespace = try! NSRegularExpression(pattern: "\\s+", options: [])
    private nonisolated static let patternFlightSuffix = try! NSRegularExpression(
        pattern: "\\s*\\([A-Z]{1,3}\\s*\\d{1,4}\\)\\s*$",
        options: [.caseInsensitive]
    )
    private nonisolated static let patternWeekdaySuffix = try! NSRegularExpression(
        pattern: "\\s+(?:Mon(?:day)?|Tue(?:sday)?|Wed(?:nesday)?|Thu(?:rsday)?|Fri(?:day)?|Sat(?:urday)?|Sun(?:day)?)\\b.*$",
        options: [.caseInsensitive]
    )

    nonisolated static func classify(event: CalendarEventTextSnapshot) -> CalendarEventIngestability {
        let candidates = [
            event.title,
            event.location,
            event.structuredLocationTitle,
            event.notes
        ].compactMap { $0 }

        for text in candidates where text.localizedCaseInsensitiveContains("Friend:") {
            return .none
        }

        for text in candidates where isFlightText(text) {
            return .flight
        }

        for text in candidates where isOtherTravelOrLodgingText(text) {
            return .otherTravelOrLodging
        }

        return .none
    }

    nonisolated static func shouldIngest(event: CalendarEventTextSnapshot) -> Bool {
        classify(event: event).shouldIngest
    }

    nonisolated static func shouldDecorateAsFlight(event: CalendarEventTextSnapshot) -> Bool {
        classify(event: event).shouldDecorateAsFlight
    }

    nonisolated static func parseFlightInfo(event: CalendarEventTextSnapshot) -> (from: String?, to: String?) {
        let candidates = [
            event.title ?? "",
            event.location ?? "",
            event.structuredLocationTitle ?? "",
            event.notes ?? ""
        ]

        let bestFrom: String? = nil
        var bestTo: String? = nil

        for rawText in candidates {
            let preprocessedText = preprocessCandidateText(rawText)
            let text = collapseWhitespace(preprocessedText)
            if text.isEmpty { continue }

            let nsString = text as NSString
            let range = NSRange(location: 0, length: nsString.length)

            if let match = patternCodes.firstMatch(in: text, options: [], range: range), match.numberOfRanges >= 3 {
                return (
                    nsString.substring(with: match.range(at: 1)),
                    nsString.substring(with: match.range(at: 2))
                )
            }

            if let match = patternPlane.firstMatch(in: text, options: [], range: range), match.numberOfRanges >= 3 {
                return (
                    normalizeLocationToken(nsString.substring(with: match.range(at: 1))),
                    normalizeLocationToken(nsString.substring(with: match.range(at: 2)))
                )
            }

            if let match = patternPlaneEmoji.firstMatch(in: text, options: [], range: range), match.numberOfRanges >= 3 {
                return (
                    normalizeLocationToken(nsString.substring(with: match.range(at: 1))),
                    normalizeLocationToken(nsString.substring(with: match.range(at: 2)))
                )
            }

            if let match = patternFromTo.firstMatch(in: text, options: [], range: range), match.numberOfRanges >= 3 {
                return (
                    normalizeLocationToken(nsString.substring(with: match.range(at: 1))),
                    normalizeLocationToken(nsString.substring(with: match.range(at: 2)))
                )
            }

            if let match = patternFlightNumberRoute.firstMatch(in: text, options: [], range: range),
               match.numberOfRanges >= 3 {
                return (
                    normalizeLocationToken(nsString.substring(with: match.range(at: 1))),
                    normalizeLocationToken(nsString.substring(with: match.range(at: 2)))
                )
            }

            do {
                let preprocessedNSString = preprocessedText as NSString
                let preprocessedRange = NSRange(location: 0, length: preprocessedNSString.length)
                if let match = patternLineRoute.firstMatch(in: preprocessedText, options: [], range: preprocessedRange),
                   match.numberOfRanges >= 3 {
                    return (
                        normalizeLocationToken(preprocessedNSString.substring(with: match.range(at: 1))),
                        normalizeLocationToken(preprocessedNSString.substring(with: match.range(at: 2)))
                    )
                }
            }

            if bestTo == nil,
               let match = patternTo.firstMatch(in: text, options: [], range: range),
               match.numberOfRanges >= 2 {
                bestTo = normalizeLocationToken(nsString.substring(with: match.range(at: 1)))
            }

            if bestTo == nil,
               let match = patternHotel.firstMatch(in: text, options: [], range: range),
               match.numberOfRanges >= 2 {
                bestTo = normalizeLocationToken(nsString.substring(with: match.range(at: 1)))
            }
        }

        return (bestFrom, bestTo)
    }

    private nonisolated static func isFlightText(_ text: String) -> Bool {
        text.contains("✈") || text.localizedCaseInsensitiveContains("Flight")
    }

    private nonisolated static func isOtherTravelOrLodgingText(_ text: String) -> Bool {
        text.contains("🚆")
        || text.contains("🚄")
        || text.contains("⛴")
        || text.contains("🏨")
        || text.localizedCaseInsensitiveContains("Train")
        || text.localizedCaseInsensitiveContains("Ferry")
        || text.localizedCaseInsensitiveContains("Bus")
        || text.localizedCaseInsensitiveContains("Hotel")
    }

    private nonisolated static func preprocessCandidateText(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }

        let scalars = raw.unicodeScalars.lazy.compactMap { scalar -> UnicodeScalar? in
            switch scalar.value {
            case 0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF:
                return nil
            case 0x00A0:
                return " "
            default:
                return scalar
            }
        }
        return String(String.UnicodeScalarView(scalars))
    }

    private nonisolated static func collapseWhitespace(_ raw: String) -> String {
        let range = NSRange(location: 0, length: (raw as NSString).length)
        return patternWhitespace.stringByReplacingMatches(in: raw, options: [], range: range, withTemplate: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func normalizeLocationToken(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let range1 = NSRange(location: 0, length: (value as NSString).length)
        value = patternFlightSuffix.stringByReplacingMatches(in: value, options: [], range: range1, withTemplate: "")

        let range2 = NSRange(location: 0, length: (value as NSString).length)
        value = patternWeekdaySuffix.stringByReplacingMatches(in: value, options: [], range: range2, withTemplate: "")

        let range3 = NSRange(location: 0, length: (value as NSString).length)
        value = patternWhitespace.stringByReplacingMatches(in: value, options: [], range: range3, withTemplate: " ")
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)

        var shouldContinue = true
        while shouldContinue, let scalar = value.unicodeScalars.last {
            switch scalar.value {
            case 46, 44, 59, 58, 33, 63, 41: // ".,;:!?)"
                value.unicodeScalars.removeLast()
            default:
                shouldContinue = false
            }
        }

        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
