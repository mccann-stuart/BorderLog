
import Foundation

// Mimic the logic from CalendarSignalIngestor
func parseFlightInfo(text: String) -> (from: String?, to: String?) {
    let nsString = text as NSString
    let range = NSRange(location: 0, length: nsString.length)

    // Patterns from current implementation
    let patternFromTo = try? NSRegularExpression(pattern: "from\\s+(.+?)\\s+to\\s+(.+)", options: [.caseInsensitive])
    let patternTo = try? NSRegularExpression(pattern: "flight\\s+to\\s+(.+)", options: [.caseInsensitive])
    let patternPlane = try? NSRegularExpression(pattern: "(.+?)\\s*✈\\s*(.+)", options: [])
    let patternPlaneEmoji = try? NSRegularExpression(pattern: "(.+?)\\s*✈️\\s*(.+)", options: [])
    let patternCodes = try? NSRegularExpression(pattern: "\\b([A-Z]{3})\\s*[-/]\\s*([A-Z]{3})\\b", options: [])

    var bestFrom: String?
    var bestTo: String?

    // Check "LHR - JFK" or "LHR/JFK"
    if let p = patternCodes, let match = p.firstMatch(in: text, options: [], range: range) {
        if match.numberOfRanges >= 3 {
            return (
                nsString.substring(with: match.range(at: 1)),
                nsString.substring(with: match.range(at: 2))
            )
        }
    }

    // Check "A ✈ B"
    if let p = patternPlane, let match = p.firstMatch(in: text, options: [], range: range) {
        if match.numberOfRanges >= 3 {
            return (
                nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines),
                nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    if let p = patternPlaneEmoji, let match = p.firstMatch(in: text, options: [], range: range) {
        if match.numberOfRanges >= 3 {
            return (
                nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines),
                nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    // Check "From A to B"
    if let p = patternFromTo, let match = p.firstMatch(in: text, options: [], range: range) {
        if match.numberOfRanges >= 3 {
            return (
                nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines),
                nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    // Check "Flight to B"
    if bestTo == nil {
        if let p = patternTo, let match = p.firstMatch(in: text, options: [], range: range) {
            if match.numberOfRanges >= 2 {
                bestTo = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    return (bestFrom, bestTo)
}

let input = "✈ JNB → LHR • BA 56"
let (from, to) = parseFlightInfo(text: input)
print("Input: '\(input)'")
print("Parsed From: '\(from ?? "nil")'")
print("Parsed To: '\(to ?? "nil")'")

// Also check variants
let variants = [
    "✈ JNB → LHR",
    "JNB → LHR",
    "Flight JNB → LHR",
    "✈ JNB -> LHR"
]

for v in variants {
    let (f, t) = parseFlightInfo(text: v)
    print("Input: '\(v)' -> From: \(f ?? "nil"), To: \(t ?? "nil")")
}
