import SwiftUI
import SwiftData

struct MainNavigationView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var selectedTab = 0
    @State private var isShowingSettings = false
    @State private var isShowingAccount = false
    @State private var isPresentingAddStay = false
    @State private var isPresentingAddOverride = false

    @AppStorage("didBootstrapInference") private var didBootstrapInference = false
    @State private var locationService = LocationSampleService()
    @State private var didAttemptLaunchLocationCapture = false
    
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
                        .toolbar {
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                settingsMenu
                                
                                Menu {
                                    Button {
                                        isPresentingAddStay = true
                                    } label: {
                                        Label("Add Stay", systemImage: "airplane")
                                    }
                                    
                                    Button {
                                        isPresentingAddOverride = true
                                    } label: {
                                        Label("Add Day Override", systemImage: "calendar.badge.exclamationmark")
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                }
                            }
                        }
                }
                .tag(0)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                
                NavigationStack {
                    ContentView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                settingsMenu
                            }
                        }
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
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $isShowingAccount) {
            UserAccountView()
        }
        .sheet(isPresented: $isPresentingAddStay) {
            NavigationStack {
                StayEditorView()
            }
        }
        .sheet(isPresented: $isPresentingAddOverride) {
            NavigationStack {
                DayOverrideEditorView()
            }
        }
        .task(id: hasCompletedOnboarding) {
            await captureTodayLocationIfNeeded()
        }
        .task(id: hasCompletedOnboarding) {
            guard hasCompletedOnboarding else { return }
            let container = modelContext.container

            if !didBootstrapInference {
                didBootstrapInference = true
                let recomputeService = LedgerRecomputeService(modelContainer: container)
                await recomputeService.recomputeAll()
                let ingestor = PhotoSignalIngestor(modelContainer: container, resolver: CLGeocoderCountryResolver())
                _ = await ingestor.ingest(mode: .sequenced)
                let calendarIngestor = CalendarSignalIngestor(modelContainer: container, resolver: CLGeocoderCountryResolver())
                _ = await calendarIngestor.ingest(mode: .manualFullScan)
                return
            }

            let calendarIngestor = CalendarSignalIngestor(modelContainer: container, resolver: CLGeocoderCountryResolver())
            _ = await calendarIngestor.ingest(mode: .auto)
        }
    }
    
    private var settingsMenu: some View {
        Menu {
            if AuthenticationManager.isAppleSignInEnabled {
                Button {
                    isShowingAccount = true
                } label: {
                    Label("Account", systemImage: "person.circle")
                }
            }
            
            Button {
                isShowingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            
            Divider()
            
            Button {
                hasCompletedOnboarding = false
            } label: {
                Label("Re-Launch Setup", systemImage: "arrow.clockwise")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
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
}

#Preview {
    MainNavigationView()
        .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self, CalendarSignal.self], inMemory: true)
        .environmentObject(AuthenticationManager())
}
