//
//  GeocodeThrottleStore.swift
//  Learn
//
//  Created by Mccann Stuart on 23/02/2026.
//

import Foundation

nonisolated struct GeocodeThrottleState: Codable, Sendable {
    var timestamps: [TimeInterval]
    var blockedUntil: TimeInterval?

    init(timestamps: [TimeInterval] = [], blockedUntil: TimeInterval? = nil) {
        self.timestamps = timestamps
        self.blockedUntil = blockedUntil
    }
}

nonisolated final class GeocodeThrottleStore {
    nonisolated static let shared = GeocodeThrottleStore()
    private nonisolated static let stateKey = "borderlog.geocode.throttle.state"

    private nonisolated let defaults: UserDefaults?

    nonisolated var isAvailable: Bool {
        defaults != nil
    }

    private init() {
        if AppConfig.isAppGroupAvailable, let appGroupId = AppConfig.appGroupId, !appGroupId.isEmpty {
            defaults = UserDefaults(suiteName: appGroupId)
        } else {
            defaults = nil
        }
    }

    nonisolated func loadState() -> GeocodeThrottleState {
        guard let defaults else { return GeocodeThrottleState() }
        guard let data = defaults.data(forKey: Self.stateKey) else { return GeocodeThrottleState() }
        if let state = try? JSONDecoder().decode(GeocodeThrottleState.self, from: data) {
            return state
        }
        return GeocodeThrottleState()
    }

    nonisolated func saveState(_ state: GeocodeThrottleState) {
        guard let defaults else { return }
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.stateKey)
        defaults.synchronize()
    }

    nonisolated func update(_ transform: (inout GeocodeThrottleState) -> Void) -> GeocodeThrottleState {
        guard defaults != nil else { return GeocodeThrottleState() }
        var state = loadState()
        transform(&state)
        saveState(state)
        return state
    }
}
