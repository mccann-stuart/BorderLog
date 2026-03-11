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
            let service = LedgerRecomputeService(modelContainer: container)
            await service.fillMissingDays()
        }
    }

    var body: some Scene {
        WindowGroup {
            MainNavigationView()
                .environmentObject(authManager)
                .overlay {
                    if requireBiometrics && !isUnlocked {
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
        let pending = PendingLocationSnapshot.dequeueAll(from: AppConfig.sharedDefaults)
        guard !pending.isEmpty else { return }
        
        let context = ModelContext(sharedModelContainer)
        var dayKeysToRecompute = Set<String>()
        
        for snapshot in pending {
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
        
        do {
            try context.save()
            if !dayKeysToRecompute.isEmpty {
                Task {
                    let recomputeService = LedgerRecomputeService(modelContainer: sharedModelContainer)
                    await recomputeService.recompute(dayKeys: Array(dayKeysToRecompute))
                }
            }
        } catch {
            Self.logger.error("Failed to save ingested pending locations: \(error, privacy: .private)")
        }
    }
}
