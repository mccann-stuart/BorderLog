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
        // Optimization: Use iOS 15+ FormatStyle API instead of allocating an expensive DateFormatter
        // per row render. FormatStyle is a lightweight value type.
        var format = Date.FormatStyle(date: .abbreviated, time: .omitted)
        format.timeZone = dayTimeZone
        return day.date.formatted(format)
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

                if day.isDisputed && !day.isManuallyModified {
                    Label("Disputed", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(.caption, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.18))
                        .foregroundStyle(.orange)
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
