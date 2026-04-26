//
//  PendingLocationSnapshot.swift
//  Shared
//

import Foundation
import CryptoKit

struct PendingLocationSnapshot: Codable, Equatable, Sendable {
    var id: String
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var accuracyMeters: Double
    var sourceRaw: String
    var timeZoneId: String?
    var dayKey: String
    var countryCode: String?
    var countryName: String?

    private static let legacyDefaultsKey = "pending_location_snapshots_v1"
    private static let queueDirectoryName = "PendingLocationSnapshots"
    private static let fileExtension = "json"
    private static let maxQueuedSnapshots = 500
    private static let maxSnapshotAge: TimeInterval = 60 * 60 * 24 * 30

    init(
        id: String? = nil,
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        accuracyMeters: Double,
        sourceRaw: String,
        timeZoneId: String?,
        dayKey: String,
        countryCode: String?,
        countryName: String?
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.accuracyMeters = accuracyMeters
        self.sourceRaw = sourceRaw
        self.timeZoneId = timeZoneId
        self.dayKey = dayKey
        self.countryCode = countryCode
        self.countryName = countryName
        self.id = id ?? Self.makeID(
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            accuracyMeters: accuracyMeters,
            sourceRaw: sourceRaw
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case latitude
        case longitude
        case accuracyMeters
        case sourceRaw
        case timeZoneId
        case dayKey
        case countryCode
        case countryName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        let accuracyMeters = try container.decode(Double.self, forKey: .accuracyMeters)
        let sourceRaw = try container.decode(String.self, forKey: .sourceRaw)
        let timeZoneId = try container.decodeIfPresent(String.self, forKey: .timeZoneId)
        let dayKey = try container.decode(String.self, forKey: .dayKey)
        let countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        let countryName = try container.decodeIfPresent(String.self, forKey: .countryName)

        self.init(
            id: try container.decodeIfPresent(String.self, forKey: .id),
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            accuracyMeters: accuracyMeters,
            sourceRaw: sourceRaw,
            timeZoneId: timeZoneId,
            dayKey: dayKey,
            countryCode: countryCode,
            countryName: countryName
        )
    }

    static func enqueue(
        _ snapshot: PendingLocationSnapshot,
        in defaults: UserDefaults = AppConfig.sharedDefaults,
        fileManager: FileManager = .default,
        queueDirectoryURL: URL? = nil
    ) {
        try? enqueueThrowing(
            snapshot,
            in: defaults,
            fileManager: fileManager,
            queueDirectoryURL: queueDirectoryURL
        )
    }

    static func enqueueThrowing(
        _ snapshot: PendingLocationSnapshot,
        in defaults: UserDefaults = AppConfig.sharedDefaults,
        fileManager: FileManager = .default,
        queueDirectoryURL: URL? = nil
    ) throws {
        let directoryURL = try resolvedQueueDirectory(fileManager: fileManager, overrideURL: queueDirectoryURL)
        let fileURL = fileURL(for: snapshot.id, in: directoryURL)
        let data = try JSONEncoder.pendingSnapshotEncoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
        try pruneQueue(in: directoryURL, fileManager: fileManager, now: Date())

        // Once a file-backed write has succeeded, remove the same snapshot from
        // the legacy defaults queue so migrations do not duplicate it.
        removeLegacySnapshots(ids: [snapshot.id], from: defaults)
    }

    static func all(
        from defaults: UserDefaults = AppConfig.sharedDefaults,
        fileManager: FileManager = .default,
        queueDirectoryURL: URL? = nil
    ) -> [PendingLocationSnapshot] {
        var snapshotsByID: [String: PendingLocationSnapshot] = [:]

        if let directoryURL = try? resolvedQueueDirectory(fileManager: fileManager, overrideURL: queueDirectoryURL),
           let fileURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
           ) {
            for fileURL in fileURLs where fileURL.pathExtension == fileExtension {
                guard let data = try? Data(contentsOf: fileURL),
                      let snapshot = try? JSONDecoder.pendingSnapshotDecoder.decode(PendingLocationSnapshot.self, from: data) else {
                    continue
                }
                snapshotsByID[snapshot.id] = snapshot
            }
        }

        for snapshot in legacySnapshots(from: defaults) {
            snapshotsByID[snapshot.id] = snapshot
        }

        return snapshotsByID.values.sorted {
            if $0.timestamp == $1.timestamp {
                return $0.id < $1.id
            }
            return $0.timestamp < $1.timestamp
        }
    }

    static func dequeueAll(
        from defaults: UserDefaults,
        clearAfter: Bool = true,
        fileManager: FileManager = .default,
        queueDirectoryURL: URL? = nil
    ) -> [PendingLocationSnapshot] {
        let snapshots = all(from: defaults, fileManager: fileManager, queueDirectoryURL: queueDirectoryURL)
        if clearAfter {
            try? remove(snapshots, from: defaults, fileManager: fileManager, queueDirectoryURL: queueDirectoryURL)
        }
        return snapshots
    }

    static func remove(
        _ snapshots: [PendingLocationSnapshot],
        from defaults: UserDefaults = AppConfig.sharedDefaults,
        fileManager: FileManager = .default,
        queueDirectoryURL: URL? = nil
    ) throws {
        guard !snapshots.isEmpty else { return }
        let ids = Set(snapshots.map(\.id))
        if let directoryURL = try? resolvedQueueDirectory(fileManager: fileManager, overrideURL: queueDirectoryURL) {
            for id in ids {
                let fileURL = fileURL(for: id, in: directoryURL)
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
            }
        }
        removeLegacySnapshots(ids: ids, from: defaults)
    }

    static func removeAll(
        from defaults: UserDefaults,
        fileManager: FileManager = .default,
        queueDirectoryURL: URL? = nil
    ) {
        defaults.removeObject(forKey: legacyDefaultsKey)
        guard let directoryURL = try? resolvedQueueDirectory(fileManager: fileManager, overrideURL: queueDirectoryURL),
              let fileURLs = try? fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return
        }
        for fileURL in fileURLs where fileURL.pathExtension == fileExtension {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private static func resolvedQueueDirectory(
        fileManager: FileManager,
        overrideURL: URL?
    ) throws -> URL {
        let directoryURL: URL
        if let overrideURL {
            directoryURL = overrideURL
        } else if let appGroupURL = AppConfig.appGroupContainerURL {
            directoryURL = appGroupURL.appendingPathComponent(queueDirectoryName, isDirectory: true)
        } else {
            let fallbackRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            directoryURL = fallbackRoot
                .appendingPathComponent("BorderLog", isDirectory: true)
                .appendingPathComponent(queueDirectoryName, isDirectory: true)
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private static func fileURL(for id: String, in directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent(safeFileStem(for: id)).appendingPathExtension(fileExtension)
    }

    private static func safeFileStem(for id: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = id.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        return String(scalars)
    }

    private static func legacySnapshots(from defaults: UserDefaults) -> [PendingLocationSnapshot] {
        guard let data = defaults.data(forKey: legacyDefaultsKey) else {
            return []
        }
        if let queue = try? JSONDecoder.pendingSnapshotDecoder.decode([PendingLocationSnapshot].self, from: data) {
            return queue
        }
        return (try? JSONDecoder().decode([PendingLocationSnapshot].self, from: data)) ?? []
    }

    private static func removeLegacySnapshots(ids: Set<String>, from defaults: UserDefaults) {
        guard !ids.isEmpty else { return }
        let remaining = legacySnapshots(from: defaults).filter { !ids.contains($0.id) }
        guard !remaining.isEmpty else {
            defaults.removeObject(forKey: legacyDefaultsKey)
            return
        }
        if let data = try? JSONEncoder.pendingSnapshotEncoder.encode(remaining) {
            defaults.set(data, forKey: legacyDefaultsKey)
        }
    }

    private static func pruneQueue(
        in directoryURL: URL,
        fileManager: FileManager,
        now: Date
    ) throws {
        let snapshots = all(from: UserDefaults.standard, fileManager: fileManager, queueDirectoryURL: directoryURL)
        let expiredIDs = snapshots
            .filter { now.timeIntervalSince($0.timestamp) > maxSnapshotAge }
            .map(\.id)
        let overflowIDs = snapshots
            .sorted { $0.timestamp > $1.timestamp }
            .dropFirst(maxQueuedSnapshots)
            .map(\.id)
        for id in Set(expiredIDs + overflowIDs) {
            let fileURL = fileURL(for: id, in: directoryURL)
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }

    private static func makeID(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        accuracyMeters: Double,
        sourceRaw: String
    ) -> String {
        let raw = [
            String(format: "%.6f", timestamp.timeIntervalSince1970),
            String(format: "%.7f", latitude),
            String(format: "%.7f", longitude),
            String(format: "%.3f", accuracyMeters),
            sourceRaw
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private extension JSONEncoder {
    static var pendingSnapshotEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var pendingSnapshotDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
