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

enum CalendarFlightParsing {
    static func shouldIngest(event: CalendarEventTextSnapshot) -> Bool {
        let candidates = [
            event.title,
            event.location,
            event.structuredLocationTitle,
            event.notes
        ].compactMap { $0 }

        for text in candidates where text.localizedCaseInsensitiveContains("Friend:") {
            return false
        }

        for text in candidates where text.contains("✈") || text.localizedCaseInsensitiveContains("Flight") {
            return true
        }

        return false
    }

    static func parseFlightInfo(event: CalendarEventTextSnapshot) -> (from: String?, to: String?) {
        let candidates = [
            event.title ?? "",
            event.location ?? "",
            event.structuredLocationTitle ?? "",
            event.notes ?? ""
        ]

        let patternFromTo = try? NSRegularExpression(pattern: "from\\s+(.+?)\\s+to\\s+(.+)", options: [.caseInsensitive])
        let patternTo = try? NSRegularExpression(pattern: "flight\\s+to\\s+(.+)", options: [.caseInsensitive])
        let patternFlightNumberRoute = try? NSRegularExpression(
            pattern: "flight\\s*[:\\-]?\\s*[A-Z]{1,3}\\s*\\d{1,4}\\s+(.+?)\\s+to\\s+(.+)",
            options: [.caseInsensitive]
        )
        let patternLineRoute = try? NSRegularExpression(
            pattern: "^\\s*([\\p{L}][\\p{L}\\p{M} .'-]{1,80}?)\\s+to\\s+([\\p{L}][\\p{L}\\p{M} .'-]{1,80}?)\\s*$",
            options: [.caseInsensitive, .anchorsMatchLines]
        )
        let patternPlane = try? NSRegularExpression(pattern: "(.+?)\\s*✈\\s*(.+)", options: [])
        let patternPlaneEmoji = try? NSRegularExpression(pattern: "(.+?)\\s*✈️\\s*(.+)", options: [])
        let patternCodes = try? NSRegularExpression(pattern: "\\b([A-Z]{3})\\s*(?:[-/→]|->)\\s*([A-Z]{3})\\b", options: [])

        let bestFrom: String? = nil
        var bestTo: String? = nil

        for rawText in candidates {
            let preprocessedText = preprocessCandidateText(rawText)
            let text = collapseWhitespace(preprocessedText)
            if text.isEmpty { continue }

            let nsString = text as NSString
            let range = NSRange(location: 0, length: nsString.length)

            if let p = patternCodes, let match = p.firstMatch(in: text, options: [], range: range), match.numberOfRanges >= 3 {
                return (
                    nsString.substring(with: match.range(at: 1)),
                    nsString.substring(with: match.range(at: 2))
                )
            }

            if let p = patternPlane, let match = p.firstMatch(in: text, options: [], range: range), match.numberOfRanges >= 3 {
                return (
                    normalizeLocationToken(nsString.substring(with: match.range(at: 1))),
                    normalizeLocationToken(nsString.substring(with: match.range(at: 2)))
                )
            }

            if let p = patternPlaneEmoji, let match = p.firstMatch(in: text, options: [], range: range), match.numberOfRanges >= 3 {
                return (
                    normalizeLocationToken(nsString.substring(with: match.range(at: 1))),
                    normalizeLocationToken(nsString.substring(with: match.range(at: 2)))
                )
            }

            if let p = patternFromTo, let match = p.firstMatch(in: text, options: [], range: range), match.numberOfRanges >= 3 {
                return (
                    normalizeLocationToken(nsString.substring(with: match.range(at: 1))),
                    normalizeLocationToken(nsString.substring(with: match.range(at: 2)))
                )
            }

            if let p = patternFlightNumberRoute,
               let match = p.firstMatch(in: text, options: [], range: range),
               match.numberOfRanges >= 3 {
                return (
                    normalizeLocationToken(nsString.substring(with: match.range(at: 1))),
                    normalizeLocationToken(nsString.substring(with: match.range(at: 2)))
                )
            }

            if let p = patternLineRoute {
                let preprocessedNSString = preprocessedText as NSString
                let preprocessedRange = NSRange(location: 0, length: preprocessedNSString.length)
                if let match = p.firstMatch(in: preprocessedText, options: [], range: preprocessedRange),
                   match.numberOfRanges >= 3 {
                    return (
                        normalizeLocationToken(preprocessedNSString.substring(with: match.range(at: 1))),
                        normalizeLocationToken(preprocessedNSString.substring(with: match.range(at: 2)))
                    )
                }
            }

            if bestTo == nil,
               let p = patternTo,
               let match = p.firstMatch(in: text, options: [], range: range),
               match.numberOfRanges >= 2 {
                bestTo = normalizeLocationToken(nsString.substring(with: match.range(at: 1)))
            }
        }

        return (bestFrom, bestTo)
    }

    private static func preprocessCandidateText(_ raw: String) -> String {
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
        return String(scalars)
    }

    private static func collapseWhitespace(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeLocationToken(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let flightSuffix = try? NSRegularExpression(
            pattern: "\\s*\\([A-Z]{1,3}\\s*\\d{1,4}\\)\\s*$",
            options: [.caseInsensitive]
        ) {
            let range = NSRange(location: 0, length: (value as NSString).length)
            value = flightSuffix.stringByReplacingMatches(in: value, options: [], range: range, withTemplate: "")
        }

        if let weekdaySuffix = try? NSRegularExpression(
            pattern: "\\s+(?:Mon(?:day)?|Tue(?:sday)?|Wed(?:nesday)?|Thu(?:rsday)?|Fri(?:day)?|Sat(?:urday)?|Sun(?:day)?)\\b.*$",
            options: [.caseInsensitive]
        ) {
            let range = NSRange(location: 0, length: (value as NSString).length)
            value = weekdaySuffix.stringByReplacingMatches(in: value, options: [], range: range, withTemplate: "")
        }

        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)

        while let scalar = value.unicodeScalars.last,
              CharacterSet(charactersIn: ".,;:!?)").contains(scalar) {
            value.removeLast()
        }

        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
