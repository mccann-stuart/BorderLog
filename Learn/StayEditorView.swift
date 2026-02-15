//
//  StayEditorView.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import SwiftUI
import SwiftData

struct StayEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var countryName = ""
    @State private var countryCode = ""
    @State private var region: Region = .schengen
    @State private var enteredOn = Date()
    @State private var hasExitDate = false
    @State private var exitedOn = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("Country", text: $countryName)

                    TextField("Country Code", text: $countryCode)
                        .textInputAutocapitalization(.characters)

                    Picker("Region", selection: $region) {
                        ForEach(Region.allCases) { region in
                            Text(region.rawValue).tag(region)
                        }
                    }
                }

                Section("Dates") {
                    DatePicker("Entry", selection: $enteredOn, displayedComponents: .date)

                    Toggle("Has exit date", isOn: $hasExitDate)

                    if hasExitDate {
                        DatePicker("Exit", selection: $exitedOn, in: enteredOn..., displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Stay")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveStay()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !countryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveStay() {
        let trimmedCountry = countryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let stay = Stay(
            countryName: trimmedCountry,
            countryCode: trimmedCode.isEmpty ? nil : trimmedCode.uppercased(),
            region: region,
            enteredOn: enteredOn,
            exitedOn: hasExitDate ? exitedOn : nil,
            notes: trimmedNotes
        )
        modelContext.insert(stay)
        dismiss()
    }
}

#Preview {
    StayEditorView()
        .modelContainer(for: Stay.self, inMemory: true)
}
