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

    @State private var sharedModelContainer: ModelContainer?
    @State private var initializationError: Error?

    @StateObject private var authManager = AuthenticationManager()
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("requireBiometrics") private var requireBiometrics = false
    @State private var isUnlocked = false

    init() {
        do {
            let container = try ModelContainerProvider.makeContainer()
            _sharedModelContainer = State(initialValue: container)

            Task {
                await LedgerRefreshCoordinator.shared.run {
                    let service = LedgerRecomputeService(modelContainer: container)
                    await service.fillMissingDays()
                }
            }
        } catch {
            Self.logger.critical("Failed to initialise the SwiftData container: \(error, privacy: .private)")
            _initializationError = State(initialValue: error)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if initializationError != nil {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        Text("Storage Error")
                            .font(.headline)
                        Text("The application failed to initialize its database. Please restart the application.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if let container = sharedModelContainer {
                    MainNavigationView()
                        .environmentObject(authManager)
                        .modelContainer(container)
                } else {
                    ProgressView("Initializing...")
                }
            }
            .overlay {
                if requireBiometrics && (!isUnlocked || scenePhase != .active) {
                    SecurityLockView(
                        isUnlocked: $isUnlocked,
                        canAuthenticate: scenePhase == .active
                    )
                }
            }
        }
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
        guard let container = sharedModelContainer else { return }
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
                        LedgerRecomputeRecoveryStore.shared.markDirty(dayKeys: dayKeysToRecompute)
                        try context.save()
                    }
                    try PendingLocationSnapshot.remove(pending, from: AppConfig.sharedDefaults)

                    guard !dayKeysToRecompute.isEmpty else { return }
                    let recomputeService = LedgerRecomputeService(modelContainer: container)
                    try await recomputeService.recompute(dayKeys: Array(dayKeysToRecompute))
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
