//
//  LedgerRecomputeRecoveryStore.swift
//  Learn
//

import Foundation

/// Persists ledger days that still need a successful recompute.
///
/// The state deliberately lives outside SwiftData so it survives a failed source-data
/// transaction or an unavailable model container without requiring a schema migration.
nonisolated final class LedgerRecomputeRecoveryStore: @unchecked Sendable {
    nonisolated static let storageKey = "ledgerRecomputeRecoveryState.v1"
    nonisolated static let shared = LedgerRecomputeRecoveryStore(defaults: AppConfig.sharedDefaults)

    private struct PersistedState: Codable {
        var dirtyDayKeys: [String] = []
        var dirtyDayGenerations: [String: UInt64]?
        var nextGeneration: UInt64?
        var completedSourceReconciliationVersion: Int?
    }

    /// Identifies the exact dirty writes covered by one recompute attempt.
    /// A later write to the same day receives a newer generation and therefore
    /// cannot be cleared by an older in-flight recompute.
    struct CompletionToken: Equatable, Sendable {
        fileprivate let generationsByDayKey: [String: UInt64]
    }

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    @discardableResult
    func markDirty(dayKeys: some Sequence<String>) -> CompletionToken {
        lock.lock()
        defer { lock.unlock() }
        let newKeys = Set(dayKeys.lazy.filter { !$0.isEmpty })
        guard !newKeys.isEmpty else { return CompletionToken(generationsByDayKey: [:]) }

        var state = loadState()
        var generations = state.dirtyDayGenerations ?? [:]
        var nextGeneration = max(
            state.nextGeneration ?? 0,
            generations.values.max() ?? 0
        )
        var tokenGenerations: [String: UInt64] = [:]
        tokenGenerations.reserveCapacity(newKeys.count)

        for dayKey in newKeys.sorted() {
            nextGeneration += 1
            generations[dayKey] = nextGeneration
            tokenGenerations[dayKey] = nextGeneration
        }

        state.dirtyDayGenerations = generations
        state.nextGeneration = nextGeneration
        state.dirtyDayKeys = generations.keys.sorted()
        save(state)
        return CompletionToken(generationsByDayKey: tokenGenerations)
    }

    func dirtyDayKeys() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(loadState().dirtyDayGenerations?.keys.map { $0 } ?? [])
    }

    func needsSourceReconciliation(version: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return loadState().completedSourceReconciliationVersion != version
    }

    func recordSourceReconciliation(version: Int) {
        lock.lock()
        defer { lock.unlock() }
        var state = loadState()
        state.completedSourceReconciliationVersion = version
        save(state)
    }

    func clearDirty(matching token: CompletionToken) {
        lock.lock()
        defer { lock.unlock() }
        guard !token.generationsByDayKey.isEmpty else { return }

        var state = loadState()
        var generations = state.dirtyDayGenerations ?? [:]
        let initialCount = generations.count

        for (dayKey, completedGeneration) in token.generationsByDayKey
        where generations[dayKey] == completedGeneration {
            generations.removeValue(forKey: dayKey)
        }
        guard generations.count != initialCount else { return }

        state.dirtyDayGenerations = generations
        state.dirtyDayKeys = generations.keys.sorted()
        save(state)
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func loadState() -> PersistedState {
        guard let data = defaults.data(forKey: Self.storageKey),
              var state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return PersistedState()
        }

        // Migrate the original set-only representation in place. It remains readable so
        // interrupted work recorded by builds predating generation tokens is not lost.
        if state.dirtyDayGenerations == nil {
            var nextGeneration = state.nextGeneration ?? 0
            var generations: [String: UInt64] = [:]
            generations.reserveCapacity(state.dirtyDayKeys.count)
            for dayKey in state.dirtyDayKeys.sorted() where !dayKey.isEmpty {
                nextGeneration += 1
                generations[dayKey] = nextGeneration
            }
            state.dirtyDayGenerations = generations
            state.nextGeneration = nextGeneration
        }
        return state
    }

    private func save(_ state: PersistedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
