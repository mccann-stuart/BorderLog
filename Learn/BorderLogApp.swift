//
//  BorderLogApp.swift
//  Learn
//
//  Created by Mccann Stuart on 13/02/2026.
//

import SwiftUI
import SwiftData
import os

@main
struct BorderLogApp: App {
    private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "BorderLogApp")

    var sharedModelContainer: ModelContainer = ModelContainerProvider.makeContainer()

    @StateObject private var authManager = AuthenticationManager()
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("requireBiometrics") private var requireBiometrics = false
    @State private var isUnlocked = false

    init() {
        let container = sharedModelContainer
        Task {
            await LedgerRefreshCoordinator.shared.run {
                let service = LedgerRecomputeService(modelContainer: container)
                await service.fillMissingDays()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            MainNavigationView()
                .environmentObject(authManager)
                .overlay {
                    if requireBiometrics && (!isUnlocked || scenePhase != .active) {
                        SecurityLockView(isUnlocked: $isUnlocked)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                ingestPendingLocations()
            } else if newPhase == .background {
                if requireBiometrics {
                    isUnlocked = false
                }
            }
        }
    }

    private func ingestPendingLocations() {
        let container = sharedModelContainer
        Task {
            await LedgerRefreshCoordinator.shared.run {
                let pending = PendingLocationSnapshot.all(from: AppConfig.sharedDefaults)
                guard !pending.isEmpty else { return }

                let context = ModelContext(container)
                var dayKeysToRecompute = Set<String>()

                do {
                    for snapshot in pending {
                        guard try !Self.hasStoredLocationSample(matching: snapshot, in: context) else {
                            continue
                        }
                        let sample = LocationSample(
                            timestamp: snapshot.timestamp,
                            latitude: snapshot.latitude,
                            longitude: snapshot.longitude,
                            accuracyMeters: snapshot.accuracyMeters,
                            source: LocationSampleSource(rawValue: snapshot.sourceRaw) ?? .widget,
                            timeZoneId: snapshot.timeZoneId,
                            dayKey: snapshot.dayKey,
                            countryCode: snapshot.countryCode,
                            countryName: snapshot.countryName
                        )
                        context.insert(sample)
                        dayKeysToRecompute.insert(snapshot.dayKey)
                    }

                    if context.hasChanges {
                        try context.save()
                    }
                    try PendingLocationSnapshot.remove(pending, from: AppConfig.sharedDefaults)

                    guard !dayKeysToRecompute.isEmpty else { return }
                    let recomputeService = LedgerRecomputeService(modelContainer: container)
                    await recomputeService.recompute(dayKeys: Array(dayKeysToRecompute))
                } catch {
                    Self.logger.error("Failed to save ingested pending locations: \(error, privacy: .private)")
                }
            }
        }
    }

    private static func hasStoredLocationSample(
        matching snapshot: PendingLocationSnapshot,
        in context: ModelContext
    ) throws -> Bool {
        let timestamp = snapshot.timestamp
        let latitude = snapshot.latitude
        let longitude = snapshot.longitude
        let accuracyMeters = snapshot.accuracyMeters
        let sourceRaw = snapshot.sourceRaw
        var descriptor = FetchDescriptor<LocationSample>(
            predicate: #Predicate { sample in
                sample.timestamp == timestamp &&
                sample.latitude == latitude &&
                sample.longitude == longitude &&
                sample.accuracyMeters == accuracyMeters &&
                sample.sourceRaw == sourceRaw
            }
        )
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }
}
