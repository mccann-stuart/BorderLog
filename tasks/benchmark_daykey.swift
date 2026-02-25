import Foundation

enum DayKey {
    static let format = "yyyy-MM-dd"

    // Existing implementation using cached DateFormatter
    static func makeOriginal(from date: Date, timeZone: TimeZone) -> String {
        formatter(for: timeZone).string(from: date)
    }

    private static func formatter(for timeZone: TimeZone) -> DateFormatter {
        let key = "DayKeyFormatter_" + timeZone.identifier
        let dictionary = Thread.current.threadDictionary

        if let formatter = dictionary[key] as? DateFormatter {
            return formatter
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format

        dictionary[key] = formatter
        return formatter
    }

    // New implementation using Calendar components
    static func makeOptimized(from date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        // Manual string construction is often faster than DateFormatter
        // String(format:) is generally slow, string interpolation is better but still has overhead.
        // Let's try direct concatenation or interpolation.

        let year = components.year!
        let month = components.month!
        let day = components.day!

        // Efficient zero padding
        return "\(year)-\(month < 10 ? "0" : "")\(month)-\(day < 10 ? "0" : "")\(day)"
    }
}

let iterations = 100_000
let date = Date()
let timeZone = TimeZone.current

// Warmup
_ = DayKey.makeOriginal(from: date, timeZone: timeZone)
_ = DayKey.makeOptimized(from: date, timeZone: timeZone)

let startOriginal = Date()
for _ in 0..<iterations {
    _ = DayKey.makeOriginal(from: date, timeZone: timeZone)
}
let endOriginal = Date()
print("Original implementation: \(endOriginal.timeIntervalSince(startOriginal)) seconds")

let startOptimized = Date()
for _ in 0..<iterations {
    _ = DayKey.makeOptimized(from: date, timeZone: timeZone)
}
let endOptimized = Date()
print("Optimized implementation: \(endOptimized.timeIntervalSince(startOptimized)) seconds")

print("Speedup: \(String(format: "%.2fx", (endOriginal.timeIntervalSince(startOriginal) / endOptimized.timeIntervalSince(startOptimized))))")
