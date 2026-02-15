//
//  StayDetailView.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import SwiftUI
import SwiftData

struct StayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var stay: Stay
    @State private var isConfirmingDelete = false

    var body: some View {
        Form {
            Section("Location") {
                TextField("Country", text: $stay.countryName)

                TextField("Country Code", text: countryCodeBinding)
                    .textInputAutocapitalization(.characters)

                Picker("Region", selection: regionBinding) {
                    ForEach(Region.allCases) { region in
                        Text(region.rawValue).tag(region)
                    }
                }
            }

            Section("Dates") {
                DatePicker("Entry", selection: $stay.enteredOn, displayedComponents: .date)

                Toggle("Has exit date", isOn: hasExitDateBinding)

                if stay.exitedOn != nil {
                    DatePicker(
                        "Exit",
                        selection: exitDateBinding,
                        in: stay.enteredOn...,
                        displayedComponents: .date
                    )
                }

                Text("Duration: \(stay.durationInDays()) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notes") {
                TextField("Notes", text: notesBinding, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(stay.countryName)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete this stay?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                modelContext.delete(stay)
                dismiss()
            }
        }
    }

    private var countryCodeBinding: Binding<String> {
        Binding(
            get: { stay.countryCode ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                stay.countryCode = trimmed.isEmpty ? nil : trimmed.uppercased()
            }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { stay.notes },
            set: { stay.notes = $0 }
        )
    }

    private var regionBinding: Binding<Region> {
        Binding(
            get: { stay.region },
            set: { stay.region = $0 }
        )
    }

    private var hasExitDateBinding: Binding<Bool> {
        Binding(
            get: { stay.exitedOn != nil },
            set: { hasExit in
                if hasExit {
                    stay.exitedOn = stay.exitedOn ?? stay.enteredOn
                } else {
                    stay.exitedOn = nil
                }
            }
        )
    }

    private var exitDateBinding: Binding<Date> {
        Binding(
            get: { stay.exitedOn ?? stay.enteredOn },
            set: { stay.exitedOn = $0 }
        )
    }
}

#Preview {
    let container = try! ModelContainer(for: Stay.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let stay = Stay(countryName: "Portugal", region: .schengen, enteredOn: Date())
    container.mainContext.insert(stay)

    return NavigationStack {
        StayDetailView(stay: stay)
    }
    .modelContainer(container)
}
