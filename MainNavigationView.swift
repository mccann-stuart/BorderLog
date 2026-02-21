import SwiftUI
import SwiftData

struct MainNavigationView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var selectedTab = 0
    @State private var isShowingMenu = false
    @State private var isShowingSettings = false
    @State private var isShowingAccount = false
    @State private var isPresentingAddStay = false
    @State private var isPresentingAddOverride = false
    @State private var didBootstrapInference = false
    
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
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    isShowingMenu = true
                                } label: {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.title3)
                                }
                            }
                            
                            ToolbarItem(placement: .topBarTrailing) {
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
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    isShowingMenu = true
                                } label: {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.title3)
                                }
                            }
                        }
                }
                .tag(1)
                .tabItem {
                    Label("Details", systemImage: "list.bullet")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Side menu overlay
            if isShowingMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowingMenu = false
                        }
                    }
                
                HStack(spacing: 0) {
                    SideMenuView(
                        isShowing: $isShowingMenu,
                        isShowingSettings: $isShowingSettings,
                        isShowingAccount: $isShowingAccount,
                        selectedTab: $selectedTab
                    )
                    .frame(width: 280)
                    .background(.ultraThinMaterial)
                    .overlay(
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(.white.opacity(0.2)),
                        alignment: .trailing
                    )
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 5)
                    .transition(.move(edge: .leading))
                    
                    Spacer()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isShowingMenu)
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
            // Only bootstrap after onboarding completes
            guard hasCompletedOnboarding, !didBootstrapInference else { return }
            didBootstrapInference = true
            await LedgerRecomputeService.recomputeAll(modelContext: modelContext)
            let ingestor = PhotoSignalIngestor(modelContext: modelContext)
            _ = await ingestor.ingest(mode: .auto)
        }
    }
}

// Side menu component
private struct SideMenuView: View {
    @Binding var isShowing: Bool
    @Binding var isShowingSettings: Bool
    @Binding var isShowingAccount: Bool
    @Binding var selectedTab: Int
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
                
                Text("BorderLog")
                    .font(.system(.title, design: .rounded).bold())
                
                Text("Track your travels")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            Divider()
            
            // Menu items
            ScrollView {
                VStack(spacing: 0) {
                    MenuButton(
                        icon: "house.fill",
                        title: "Dashboard",
                        isSelected: selectedTab == 0
                    ) {
                        selectedTab = 0
                        withAnimation {
                            isShowing = false
                        }
                    }
                    
                    MenuButton(
                        icon: "list.bullet",
                        title: "Details",
                        isSelected: selectedTab == 1
                    ) {
                        selectedTab = 1
                        withAnimation {
                            isShowing = false
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)

                    if AuthenticationManager.isAppleSignInEnabled {
                        MenuButton(
                            icon: "person.circle",
                            title: "Account",
                            isSelected: false
                        ) {
                            isShowingAccount = true
                            withAnimation {
                                isShowing = false
                            }
                        }
                    }
                    
                    MenuButton(
                        icon: "gearshape",
                        title: "Settings",
                        isSelected: false
                    ) {
                        isShowingSettings = true
                        withAnimation {
                            isShowing = false
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Divider()

                if AuthenticationManager.isAppleSignInEnabled {
                    Button {
                        authManager.signOut()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .foregroundStyle(.red)
                        .font(.callout)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

// Menu button component
private struct MenuButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(.body, design: .rounded))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
    }
}

#Preview {
    MainNavigationView()
        .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self], inMemory: true)
        .environmentObject(AuthenticationManager())
}
