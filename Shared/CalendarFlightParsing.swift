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

    static func parseFlightInfo(title: String?, notes: String?) -> (from: String?, to: String?) {
        let candidates = [title ?? "", notes ?? ""]

        let patternFromTo = try? NSRegularExpression(pattern: "from\\s+(.+?)\\s+to\\s+(.+)", options: [.caseInsensitive])
        let patternTo = try? NSRegularExpression(pattern: "flight\\s+to\\s+(.+)", options: [.caseInsensitive])
        let patternPlane = try? NSRegularExpression(pattern: "(.+?)\\s*✈\\s*(.+)", options: [])
        let patternPlaneEmoji = try? NSRegularExpression(pattern: "(.+?)\\s*✈️\\s*(.+)", options: [])
        let patternCodes = try? NSRegularExpression(pattern: "\\b([A-Z]{3})\\s*(?:[-/→]|->)\\s*([A-Z]{3})\\b", options: [])

        let bestFrom: String? = nil
        var bestTo: String? = nil

        for text in candidates {
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
                    nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines),
                    nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            if let p = patternPlaneEmoji, let match = p.firstMatch(in: text, options: [], range: range), match.numberOfRanges >= 3 {
                return (
                    nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines),
                    nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            if let p = patternFromTo, let match = p.firstMatch(in: text, options: [], range: range), match.numberOfRanges >= 3 {
                return (
                    nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines),
                    nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            if bestTo == nil,
               let p = patternTo,
               let match = p.firstMatch(in: text, options: [], range: range),
               match.numberOfRanges >= 2 {
                bestTo = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return (bestFrom, bestTo)
    }
}
