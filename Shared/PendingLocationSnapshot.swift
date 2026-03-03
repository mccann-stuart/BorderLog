//
//  PendingLocationSnapshot.swift
//  Shared
//

import Foundation

struct PendingLocationSnapshot: Codable, Equatable {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var accuracyMeters: Double
    var sourceRaw: String
    var timeZoneId: String?
    var dayKey: String
    var countryCode: String?
    var countryName: String?
    
    private static let defaultsKey = "pending_location_snapshots_v1"
    
    static func enqueue(_ snapshot: PendingLocationSnapshot, in defaults: UserDefaults) {
        var queue = dequeueAll(from: defaults, clearAfter: false)
        queue.append(snapshot)
        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: defaultsKey)
        }
    }
    
    static func dequeueAll(from defaults: UserDefaults, clearAfter: Bool = true) -> [PendingLocationSnapshot] {
        guard let data = defaults.data(forKey: defaultsKey),
              let queue = try? JSONDecoder().decode([PendingLocationSnapshot].self, from: data) else {
            return []
        }
        if clearAfter {
            defaults.removeObject(forKey: defaultsKey)
        }
        return queue
    }
}
