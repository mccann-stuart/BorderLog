//
//  CalendarSourceSelection.swift
//  Learn
//

import Foundation

/// A stable, EventKit-free description of a calendar that can be persisted as a source choice.
nonisolated struct CalendarSourceReference: Codable, Hashable, Identifiable, Sendable {
    let identifier: String
    let title: String
    let sourceIdentifier: String
    let sourceTitle: String

    nonisolated var id: String { identifier }

    init(
        identifier: String,
        title: String,
        sourceIdentifier: String,
        sourceTitle: String
    ) {
        self.identifier = identifier
        self.title = title
        self.sourceIdentifier = sourceIdentifier
        self.sourceTitle = sourceTitle
    }
}

nonisolated struct CalendarSourceResolution: Equatable, Sendable {
    /// Identifiers that currently exist and should be passed to the calendar importer.
    let selectedIdentifiers: Set<String>

    /// The selection with any uniquely matched identifier changes applied.
    /// Unavailable references remain present so a temporarily missing calendar is not forgotten.
    let migratedSelection: CalendarSourceSelection
    let unavailableReferences: [CalendarSourceReference]
}

nonisolated enum CalendarSourceSelection: Codable, Hashable, Sendable {
    case all
    case selected([CalendarSourceReference])

    private enum CodingKeys: String, CodingKey {
        case mode
        case references
    }

    private enum Mode: String, Codable {
        case all
        case selected
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Mode.self, forKey: .mode) {
        case .all:
            self = .all
        case .selected:
            self = .selected(
                try container.decodeIfPresent([CalendarSourceReference].self, forKey: .references) ?? []
            )
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .all:
            try container.encode(Mode.all, forKey: .mode)
        case .selected(let references):
            try container.encode(Mode.selected, forKey: .mode)
            try container.encode(references, forKey: .references)
        }
    }

    nonisolated var summary: String {
        switch self {
        case .all:
            return "All"
        case .selected(let references):
            let count = Set(references.map(\.identifier)).count
            return count == 0 ? "None" : "\(count) selected"
        }
    }

    /// Resolves the persisted choice against calendars currently returned by the platform.
    ///
    /// EventKit calendar identifiers can change after a full sync. When an identifier is no
    /// longer present, a reference is remapped only when its source identifier and title identify
    /// exactly one available calendar. Ambiguous and unavailable references remain persisted but
    /// are omitted from `selectedIdentifiers` until they can be resolved safely.
    nonisolated func resolve(
        available: [CalendarSourceReference]
    ) -> CalendarSourceResolution {
        switch self {
        case .all:
            return CalendarSourceResolution(
                selectedIdentifiers: Set(available.map(\.identifier)),
                migratedSelection: .all,
                unavailableReferences: []
            )

        case .selected(let references):
            let availableByIdentifier = Dictionary(
                available.map { ($0.identifier, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            var resolvedReferences: [CalendarSourceReference] = []
            var unavailableReferences: [CalendarSourceReference] = []
            var migratedReferences: [CalendarSourceReference] = []

            for reference in references {
                if let exactMatch = availableByIdentifier[reference.identifier] {
                    resolvedReferences.append(exactMatch)
                    migratedReferences.append(exactMatch)
                    continue
                }

                let fallbackMatches = available.filter {
                    $0.sourceIdentifier == reference.sourceIdentifier
                        && $0.title == reference.title
                }
                if fallbackMatches.count == 1, let fallbackMatch = fallbackMatches.first {
                    resolvedReferences.append(fallbackMatch)
                    migratedReferences.append(fallbackMatch)
                } else {
                    unavailableReferences.append(reference)
                    migratedReferences.append(reference)
                }
            }

            return CalendarSourceResolution(
                selectedIdentifiers: Set(resolvedReferences.map(\.identifier)),
                migratedSelection: .selected(Self.uniqued(migratedReferences)),
                unavailableReferences: Self.uniqued(unavailableReferences)
            )
        }
    }

    private nonisolated static func uniqued(
        _ references: [CalendarSourceReference]
    ) -> [CalendarSourceReference] {
        var seen = Set<CalendarSourceReference>()
        return references.filter { seen.insert($0).inserted }
    }
}

/// Pure presentation rules shared by Settings and its deterministic tests.
nonisolated enum CalendarSourceSelectionViewState {
    static func canApply(
        draft: CalendarSourceSelection,
        applied: CalendarSourceSelection,
        hasReadAccess: Bool,
        isApplying: Bool
    ) -> Bool {
        hasReadAccess && !isApplying && draft != applied
    }

    static func duplicateTitleLabel(
        for reference: CalendarSourceReference,
        among available: [CalendarSourceReference]
    ) -> String? {
        let matches = available
            .filter {
                $0.sourceIdentifier == reference.sourceIdentifier
                    && $0.title == reference.title
            }
            .sorted { $0.identifier < $1.identifier }

        guard matches.count > 1,
              let index = matches.firstIndex(where: { $0.identifier == reference.identifier }) else {
            return nil
        }
        return "Calendar \(index + 1)"
    }
}

/// Persists the source choice separately from SwiftData so it is available before ingestion.
nonisolated final class CalendarSourceSelectionStore: @unchecked Sendable {
    nonisolated static let shared = CalendarSourceSelectionStore()

    private static let selectionStorageKey = "calendarSourceSelection.v1"
    private static let rebuildStorageKey = "calendarSourceSelectionNeedsRebuild.v1"

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = AppConfig.sharedDefaults) {
        self.defaults = defaults
    }

    func load() -> CalendarSourceSelection {
        lock.lock()
        defer { lock.unlock() }

        guard let data = defaults.data(forKey: Self.selectionStorageKey),
              let selection = try? JSONDecoder().decode(CalendarSourceSelection.self, from: data) else {
            return .all
        }
        return selection
    }

    func save(
        _ selection: CalendarSourceSelection,
        markingRebuild: Bool
    ) throws {
        let data = try JSONEncoder().encode(selection)

        lock.lock()
        defer { lock.unlock() }
        defaults.set(data, forKey: Self.selectionStorageKey)
        if markingRebuild {
            defaults.set(true, forKey: Self.rebuildStorageKey)
        }
    }

    var needsRebuild: Bool {
        lock.lock()
        defer { lock.unlock() }
        return defaults.bool(forKey: Self.rebuildStorageKey)
    }

    func markRebuildCompleted() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: Self.rebuildStorageKey)
    }
}
