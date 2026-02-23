import SwiftUI
import SwiftData
import Photos

struct MainNavigationView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasPromptedPhotos") private var hasPromptedPhotos = false
    
    @State private var selectedTab = 0

    @AppStorage("didBootstrapInference") private var didBootstrapInference = false
    @State private var locationService = LocationSampleService()
    @State private var didAttemptLaunchLocationCapture = false
    @State private var isBootstrappingInference = false
    @State private var isBootstrappingPhotoScan = false
    
    var body: some View {
        ZStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                LinearGradient(colors: [.blue.opacity(0.05), .purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .ignoresSafeArea()
            // Main content with tab view
            TabView(selection: $selectedTab) {
                NavigationStack {
                    DashboardView()
                        .navigationTitle("Dashboard")
                }
                .tag(0)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                
                NavigationStack {
                    ContentView()
                }
                .tag(1)
                .tabItem {
                    Label("Details", systemImage: "list.bullet")
                }
                
                NavigationStack {
                    SettingsView()
                }
                .tag(2)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .fullScreenCover(isPresented: .init(get: { !hasCompletedOnboarding }, set: { _ in })) {
            OnboardingView()
                .environmentObject(authManager)
        }
        .task(id: hasCompletedOnboarding) {
            await captureTodayLocationIfNeeded()
        }
        .task(id: hasCompletedOnboarding) {
            await bootstrapInferenceIfNeeded()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await bootstrapPhotoScanIfNeeded() }
        }
    }
    

    @MainActor
    private func captureTodayLocationIfNeeded() async {
        guard hasCompletedOnboarding else { return }
        guard !didAttemptLaunchLocationCapture else { return }
        didAttemptLaunchLocationCapture = true

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        do {
            let predicate = #Predicate<LocationSample> { sample in
                sample.timestamp >= startOfDay && sample.timestamp < endOfDay
            }
            var fetch = FetchDescriptor<LocationSample>(predicate: predicate)
            fetch.fetchLimit = 1
            let existing = try modelContext.fetch(fetch)
            if !existing.isEmpty {
                return
            }
        } catch {
            // If fetching fails, still attempt a best-effort capture.
        }

        _ = await locationService.captureAndStoreBurst(
            source: .app,
            modelContext: modelContext
        )
    }

    @MainActor
    private func bootstrapInferenceIfNeeded() async {
        guard hasCompletedOnboarding else { return }
        guard !isBootstrappingInference else { return }

        isBootstrappingInference = true
        defer { isBootstrappingInference = false }

        let container = modelContext.container

        if !didBootstrapInference {
            let recomputeService = LedgerRecomputeService(modelContainer: container)
            await recomputeService.recomputeAll()

            await bootstrapPhotoScanIfNeeded()

            let calendarIngestor = CalendarSignalIngestor(modelContainer: container, resolver: CLGeocoderCountryResolver())
            _ = await calendarIngestor.ingest(mode: .manualFullScan)
            didBootstrapInference = true
            return
        }

        await bootstrapPhotoScanIfNeeded()

        let calendarIngestor = CalendarSignalIngestor(modelContainer: container, resolver: CLGeocoderCountryResolver())
        _ = await calendarIngestor.ingest(mode: .auto)
    }

    @MainActor
    private func bootstrapPhotoScanIfNeeded() async {
        guard hasCompletedOnboarding else { return }
        guard !isBootstrappingPhotoScan else { return }

        isBootstrappingPhotoScan = true
        defer { isBootstrappingPhotoScan = false }

        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined, hasPromptedPhotos {
            status = await waitForPhotoAuthorizationResolution()
        }

        guard status == .authorized || status == .limited else { return }
        guard needsPhotoBootstrap() else { return }

        let ingestor = PhotoSignalIngestor(modelContainer: modelContext.container, resolver: CLGeocoderCountryResolver())
        _ = await ingestor.ingest(mode: .sequenced)
    }

    @MainActor
    private func needsPhotoBootstrap() -> Bool {
        let descriptor = FetchDescriptor<PhotoIngestState>()
        guard let state = try? modelContext.fetch(descriptor).first else {
            return true
        }
        return !state.fullScanCompleted
    }

    @MainActor
    private func waitForPhotoAuthorizationResolution() async -> PHAuthorizationStatus {
        let maxAttempts = 50
        for _ in 0..<maxAttempts {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if status != .notDetermined {
                return status
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
}

#Preview {
    MainNavigationView()
        .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self, CalendarSignal.self], inMemory: true)
        .environmentObject(AuthenticationManager())
}
