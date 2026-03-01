//
//  PresenceDayRow.swift
//  Learn
//

import SwiftUI
import Foundation

struct PresenceDayRow: View {
    let day: PresenceDay

    private var dayTimeZone: TimeZone {
        if let id = day.timeZoneId, let tz = TimeZone(identifier: id) {
            return tz
        }
        return .current
    }

    private var dayText: String {
        // ⚡ Bolt Optimization: Use lightweight Date.FormatStyle instead of expensive DateFormatter
        // This prevents allocating a new DateFormatter every time this row view re-renders,
        // which significantly improves scrolling performance in long lists.
        var style = Date.FormatStyle.dateTime.year().month().day()
        style.timeZone = dayTimeZone
        return day.date.formatted(style)
    }

    private var countryText: String {
        if let name = day.countryName ?? day.countryCode {
            return name
        }
        return "Unknown"
    }

    private var confidenceColor: Color {
        switch day.confidenceLabel {
        case .high: return .green
        case .medium: return .orange
        case .low: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(countryText)
                    .font(.system(.headline, design: .rounded))

                if day.isOverride {
                    Text("Override")
                        .font(.system(.caption, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                } else if day.stayCount > 0 {
                    Text("Stay")
                        .font(.system(.caption, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }

                if Calendar.current.isDateInToday(day.date) {
                    Text("Today")
                        .font(.system(.caption, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            HStack {
                Text(dayText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(day.confidenceLabel.rawValue.capitalized)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(confidenceColor)
            }
        }
        .padding(.vertical, 4)
    }
}
