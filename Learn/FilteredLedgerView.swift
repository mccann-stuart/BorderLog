import SwiftUI
import SwiftData

struct FilteredLedgerView: View {
    let days: [PresenceDay]
    let title: String
    
    var body: some View {
        List {
            if days.isEmpty {
                ContentUnavailableView(
                    "No days found",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("All days in this period have known locations.")
                )
            } else {
                ForEach(days) { day in
                    NavigationLink {
                        PresenceDayDetailView(day: day)
                    } label: {
                        PresenceDayRow(day: day)
                    }
                }
            }
        }
        .navigationTitle(title)
        .scrollContentBackground(.hidden)
        .background {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                LinearGradient(colors: [.blue.opacity(0.05), .purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .ignoresSafeArea()
        }
    }
}
