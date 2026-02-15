//
//  StayDetailView.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import SwiftUI
import SwiftData

struct StayDetailView: View {
    let stay: Stay

    var body: some View {
        StayEditorView(stay: stay)
    }
}

#Preview {
    StayDetailView(stay: Stay(countryName: "Portugal", region: .schengen, enteredOn: Date()))
        .modelContainer(for: [Stay.self, DayOverride.self], inMemory: true)
}
