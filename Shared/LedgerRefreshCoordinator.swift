//
//  LedgerRefreshCoordinator.swift
//  Shared
//

import Foundation

actor LedgerRefreshCoordinator {
    static let shared = LedgerRefreshCoordinator()

    private var isRunning = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []

    func run<T>(_ operation: () async throws -> T) async rethrows -> T {
        await waitForTurn()
        defer { finishTurn() }
        return try await operation()
    }

    func snapshotConsistency() -> String {
        isRunning ? "inProgress" : "quiescent"
    }

    func waitForQuiescence() async {
        guard isRunning else { return }
        await withCheckedContinuation { continuation in
            idleWaiters.append(continuation)
        }
    }

    private func waitForTurn() async {
        if !isRunning {
            isRunning = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func finishTurn() {
        if waiters.isEmpty {
            isRunning = false
            let idle = idleWaiters
            idleWaiters.removeAll()
            for continuation in idle {
                continuation.resume()
            }
        } else {
            let next = waiters.removeFirst()
            next.resume()
        }
    }
}
