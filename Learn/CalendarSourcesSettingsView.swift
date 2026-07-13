import EventKit
import SwiftData
import SwiftUI

struct CalendarSourcesSettingsView: View {
    private struct CalendarOption: Identifiable {
        let reference: CalendarSourceReference
        let colour: Color

        var id: String { reference.identifier }
    }

    private struct CalendarSourceGroup: Identifiable {
        let sourceIdentifier: String
        let sourceTitle: String
        let calendars: [CalendarOption]

        var id: String { sourceIdentifier }
    }

    private struct CalendarGroupSection: View {
        let group: CalendarSourceGroup
        let availableReferences: [CalendarSourceReference]
        let selectedIdentifiers: Set<String>
        let onToggle: (CalendarSourceReference) -> Void

        var body: some View {
            Section(group.sourceTitle) {
                ForEach(group.calendars) { calendar in
                    Button {
                        onToggle(calendar.reference)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(calendar.colour)
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(calendar.reference.title)
                                    .foregroundStyle(.primary)

                                if let duplicateLabel = CalendarSourceSelectionViewState.duplicateTitleLabel(
                                    for: calendar.reference,
                                    among: availableReferences
                                ) {
                                    Text(duplicateLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if selectedIdentifiers.contains(calendar.reference.identifier) {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Binding private var selection: CalendarSourceSelection
    @State private var draftSelection: CalendarSourceSelection
    @State private var availableCalendars: [CalendarOption] = []
    @State private var hasReadAccess = false
    @State private var isApplying = false
    @State private var applyError: String?

    private let selectionStore: CalendarSourceSelectionStore

    init(
        selection: Binding<CalendarSourceSelection>,
        selectionStore: CalendarSourceSelectionStore = CalendarSourceSelectionStore()
    ) {
        _selection = selection
        _draftSelection = State(initialValue: selection.wrappedValue)
        self.selectionStore = selectionStore
    }

    var body: some View {
        Group {
            if hasReadAccess {
                Form {
                    Section {
                        Button("Select All") {
                            draftSelection = .all
                        }

                        Button("Deselect All") {
                            draftSelection = .selected([])
                        }
                    } footer: {
                        Text("Only selected calendars are read for travel events. BorderLog never writes to Calendar.")
                    }

                    ForEach(calendarGroups) { group in
                        CalendarGroupSection(
                            group: group,
                            availableReferences: references,
                            selectedIdentifiers: resolution.selectedIdentifiers,
                            onToggle: toggle
                        )
                    }

                    if !unavailableReferences.isEmpty {
                        Section {
                            ForEach(unavailableReferences) { reference in
                                Button {
                                    removeUnavailable(reference)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(reference.title)
                                                .foregroundStyle(.primary)
                                            Text(reference.sourceTitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "checkmark")
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        } header: {
                            Text("Unavailable")
                        } footer: {
                            Text("Unavailable selections are remembered in case the calendar account returns. Tap one to remove it.")
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Calendar Access Required",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Allow full Calendar access in Settings before choosing calendar sources.")
                )
            }
        }
        .navigationTitle("Calendar Sources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isApplying {
                    ProgressView()
                } else {
                    Button("Apply") {
                        applySelection()
                    }
                    .disabled(!hasChanges || !hasReadAccess)
                }
            }
        }
        .disabled(isApplying)
        .alert("Unable to apply calendars", isPresented: applyErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(applyError ?? "Unknown error.")
        }
        .onAppear(perform: loadCalendars)
    }

    private var references: [CalendarSourceReference] {
        availableCalendars.map(\.reference)
    }

    private var resolution: CalendarSourceResolution {
        draftSelection.resolve(available: references)
    }

    private var unavailableReferences: [CalendarSourceReference] {
        resolution.unavailableReferences
    }

    private var calendarGroups: [CalendarSourceGroup] {
        Dictionary(grouping: availableCalendars) { option in
            option.reference.sourceIdentifier
        }
        .map { sourceIdentifier, calendars in
            CalendarSourceGroup(
                sourceIdentifier: sourceIdentifier,
                sourceTitle: calendars.first?.reference.sourceTitle ?? "Other",
                calendars: calendars.sorted {
                    $0.reference.title.localizedCaseInsensitiveCompare($1.reference.title) == .orderedAscending
                }
            )
        }
        .sorted {
            $0.sourceTitle.localizedCaseInsensitiveCompare($1.sourceTitle) == .orderedAscending
        }
    }

    private var hasChanges: Bool {
        CalendarSourceSelectionViewState.canApply(
            draft: draftSelection,
            applied: selection,
            hasReadAccess: hasReadAccess,
            isApplying: isApplying
        )
    }

    private var applyErrorPresented: Binding<Bool> {
        Binding(
            get: { applyError != nil },
            set: { if !$0 { applyError = nil } }
        )
    }

    private func loadCalendars() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            hasReadAccess = status == .fullAccess
        } else {
            hasReadAccess = status == .authorized
        }

        guard hasReadAccess else {
            availableCalendars = []
            return
        }

        let eventStore = EKEventStore()
        availableCalendars = eventStore.calendars(for: .event).map { calendar in
            CalendarOption(
                reference: CalendarSourceReference(
                    identifier: calendar.calendarIdentifier,
                    title: calendar.title,
                    sourceIdentifier: calendar.source.sourceIdentifier,
                    sourceTitle: calendar.source.title
                ),
                colour: Color(cgColor: calendar.cgColor)
            )
        }

        let migrated = selection.resolve(available: references).migratedSelection
        if migrated != selection {
            do {
                try selectionStore.save(migrated, markingRebuild: false)
                selection = migrated
                draftSelection = migrated
            } catch {
                applyError = "BorderLog could not update the saved calendar identifiers. Please try again."
            }
        } else {
            draftSelection = selection
        }
    }

    private func toggle(_ reference: CalendarSourceReference) {
        switch resolution.migratedSelection {
        case .all:
            draftSelection = .selected(references.filter { $0.identifier != reference.identifier })
        case .selected(let selected):
            if resolution.selectedIdentifiers.contains(reference.identifier) {
                draftSelection = .selected(selected.filter { $0.identifier != reference.identifier })
            } else {
                draftSelection = .selected(selected + [reference])
            }
        }
    }

    private func removeUnavailable(_ reference: CalendarSourceReference) {
        guard case .selected(let selected) = resolution.migratedSelection else { return }
        draftSelection = .selected(selected.filter { $0 != reference })
    }

    private func applySelection() {
        let appliedSelection = resolution.migratedSelection
        do {
            try selectionStore.save(appliedSelection, markingRebuild: true)
        } catch {
            applyError = "BorderLog could not save the calendar selection. Please try again."
            return
        }

        selection = appliedSelection
        draftSelection = appliedSelection
        isApplying = true
        let container = modelContext.container

        Task { @MainActor in
            defer { isApplying = false }
            do {
                try await LedgerRefreshCoordinator.shared.run {
                    let ingestor = CalendarSignalIngestor(
                        modelContainer: container,
                        resolver: CLGeocoderCountryResolver(),
                        calendarSelectionStore: selectionStore
                    )
                    _ = try await ingestor.ingest(mode: .selectionRebuild)
                }
                selection = selectionStore.load()
                dismiss()
            } catch {
                applyError = "The selection was saved, but calendar evidence could not be rebuilt. BorderLog will retry automatically."
            }
        }
    }
}
