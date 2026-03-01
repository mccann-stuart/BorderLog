//
//  SettingsView.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import SwiftUI
import SwiftData
import CoreLocation
import Photos
import EventKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext


    @State private var isConfirmingReset = false
    @State private var isConfirmingCloudKitDelete = false
    @State private var isShowingSeedAlert = false
    @State private var isDeletingCloudKitData = false
    @State private var cloudKitDeleteError: String?
    @State private var locationStatus: CLAuthorizationStatus = CLLocationManager().authorizationStatus
    @State private var photoStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var calendarStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @State private var isIngestingPhotos = false
    @State private var isIngestingCalendar = false
    @State private var locationService = LocationSampleService()
    @State private var widgetLastWriteDate: Date?
    @AppStorage("didBootstrapInference") private var didBootstrapInference = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("usePolygonMapView") private var usePolygonMapView = true
    @AppStorage("showSchengenDashboardSection") private var showSchengenDashboardSection = true
    @AppStorage("cloudKitSyncEnabled", store: AppConfig.sharedDefaults) private var cloudKitSyncEnabled = false

    private var dataManager: DataManager {
        DataManager(modelContext: modelContext)
    }

    private enum DataStoreStatus {
        case cloudKit
        case local
        case temporary
    }

    var body: some View {
            Form {
                // MARK: – Profile / About
                SwiftUI.Section {
                    NavigationLink {
                        ProfileEditView()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 46, height: 46)
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.blue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Your Profile")
                                    .font(.headline)
                                Text("Passport nationality, home country")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Text("Profile")
                }

                // MARK: – Privacy
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Local-First Storage", systemImage: "lock.shield.fill")
                            .font(.headline)

                        Text("All your travel data is stored on this device. Nothing is uploaded to any external server.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Privacy")
                }

                if AppConfig.isCloudKitFeatureEnabled {
                    // MARK: – iCloud Sync
                    Section {
                        Toggle(isOn: $cloudKitSyncEnabled) {
                            Label("iCloud Sync", systemImage: "icloud")
                        }

                        Button(role: .destructive) {
                            isConfirmingCloudKitDelete = true
                        } label: {
                            HStack {
                                Label(
                                    isDeletingCloudKitData ? "Deleting…" : "Delete iCloud Data",
                                    systemImage: isDeletingCloudKitData ? "arrow.triangle.2.circlepath" : "trash"
                                )
                                if isDeletingCloudKitData {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isDeletingCloudKitData)
                    } header: {
                        Text("iCloud Sync")
                    } footer: {
                        Text("Sync uses your iCloud private database. Changes take effect after restarting the app.")
                    }
                }


                // MARK: – Data Sources
                Section {
                    // Location
                    HStack {
                        Label("Location", systemImage: "location.fill")
                        Spacer()
                        Text(locationStatusText)
                            .foregroundStyle(locationStatusColor)
                            .font(.subheadline)
                    }

                    locationActionRow

                    HStack {
                        Label("Widget", systemImage: "square.grid.2x2")
                        Spacer()
                        if let widgetLastWriteDate {
                            Text(widgetLastWriteDate, style: .relative)
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        } else {
                            Text("No recent write")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }

                    // Photos
                    HStack {
                        Label("Photos", systemImage: "photo.fill")
                        Spacer()
                        Text(photoStatusText)
                            .foregroundStyle(photoStatusColor)
                            .font(.subheadline)
                    }

                    photoActionRow

                    if photoStatus == .authorized || photoStatus == .limited {
                        Button {
                            rescanPhotos()
                        } label: {
                            HStack {
                                Label(
                                    isIngestingPhotos ? "Scanning…" : "Scan Last 2 Years",
                                    systemImage: isIngestingPhotos ? "arrow.triangle.2.circlepath" : "arrow.clockwise"
                                )
                                if isIngestingPhotos {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isIngestingPhotos)
                    }

                    // Calendar
                    HStack {
                        Label("Calendar", systemImage: "calendar")
                        Spacer()
                        Text(calendarStatusText)
                            .foregroundStyle(calendarStatusColor)
                            .font(.subheadline)
                    }

                    calendarActionRow

                    if calendarHasReadAccess {
                        Button {
                            rescanCalendar()
                        } label: {
                            HStack {
                                Label(
                                    isIngestingCalendar ? "Scanning…" : "Scan Last 2 Years",
                                    systemImage: isIngestingCalendar ? "arrow.triangle.2.circlepath" : "arrow.clockwise"
                                )
                                if isIngestingCalendar {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isIngestingCalendar)
                    }

                    HStack {
                        Label("Data Store", systemImage: "externaldrive")
                        Spacer()
                        Text(dataStoreLabel)
                            .foregroundStyle(dataStoreColor)
                            .font(.subheadline)
                    }
                } header: {
                    Text("Data Sources")
                } footer: {
                    Text("Location, photo metadata, and read-only calendar events are used to infer which country you were in each day. All processing happens on-device, with Apple Cloud APIs/MapKit used only to resolve geo locations. No data is stored on any server or outside the app.")
                }

      

                // MARK: – Setup
                Section {
                    Button {
                        hasCompletedOnboarding = false
                    } label: {
                        Label("Re-Launch Setup", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Text("Setup")
                }

                // MARK: – Data Management
                Section {
                    Button("Reset All Data", role: .destructive) {
                        isConfirmingReset = true
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Permanently deletes all stays, day overrides, and location samples stored on this device.")
                }

                // MARK: – App Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersionString)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Storage")
                        Spacer()
                        Text("Local (on-device)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About BorderLog")
                }

                // MARK: – Customization
                Section {
                    Picker("Map Display", selection: $usePolygonMapView) {
                        Text("Dots").tag(false)
                        Text("Coloured Countries").tag(true)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Map Display")
                } footer: {
                    Text("Choose how visited countries are displayed on the map.")
                }

                // MARK: – Configuration
                Section {
                    Toggle(isOn: $showSchengenDashboardSection) {
                        Label("Schengen Zone", systemImage: "map")
                    }
                } header: {
                    Text("Configuration")
                } footer: {
                    Text("Schengen membership data is bundled with the app and updated with each release. This toggle controls visibility of the Schengen 90/180 card on Dashboard.")
                }
            }
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    Color(UIColor.systemGroupedBackground)
                    LinearGradient(
                        colors: [.blue.opacity(0.05), .purple.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog("Delete all local data?", isPresented: $isConfirmingReset) {
                Button("Delete All", role: .destructive) { resetAllData() }
            } message: {
                Text("This will remove all stays and day overrides from this device. This cannot be undone.")
            }
            .confirmationDialog("Delete iCloud data?", isPresented: $isConfirmingCloudKitDelete) {
                Button("Delete iCloud Data", role: .destructive) { deleteCloudKitData() }
            } message: {
                Text("This removes BorderLog data stored in iCloud. Local data stays on this device.")
            }
            .alert("Sample data unavailable", isPresented: $isShowingSeedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Reset all data before seeding the sample dataset.")
            }
            .alert("Unable to delete iCloud data", isPresented: cloudKitDeleteErrorPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(cloudKitDeleteError ?? "Unknown error.")
            }
            .onAppear {
                refreshPermissions()
                refreshWidgetLastWriteDate()
            }
    }

    // MARK: – Smart Location Row

    @ViewBuilder
    private var locationActionRow: some View {
        switch locationStatus {
        case .notDetermined:
            Button {
                locationService.requestAuthorizationIfNeeded()
                refreshPermissions()
            } label: {
                Label("Request Location Access", systemImage: "hand.raised")
            }
        case .denied, .restricted:
            Button {
                openAppSettings()
            } label: {
                Label("Open Settings to Enable Location", systemImage: "gear")
            }
        case .authorizedWhenInUse, .authorizedAlways:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }

    // MARK: – Smart Photos Row

    @ViewBuilder
    private var photoActionRow: some View {
        switch photoStatus {
        case .notDetermined:
            Button {
                requestPhotosAccess()
            } label: {
                Label("Request Photos Access", systemImage: "hand.raised")
            }
        case .denied, .restricted:
            Button {
                openAppSettings()
            } label: {
                Label("Open Settings to Enable Photos", systemImage: "gear")
            }
        case .authorized, .limited:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }

    // MARK: – Smart Calendar Row

    @ViewBuilder
    private var calendarActionRow: some View {
        switch calendarStatus {
        case .notDetermined:
            Button {
                requestCalendarAccess()
            } label: {
                Label("Request Calendar Access", systemImage: "hand.raised")
            }
        case .denied, .restricted:
            Button {
                openAppSettings()
            } label: {
                Label("Open Settings to Enable Calendar", systemImage: "gear")
            }
        case .writeOnly:
            Button {
                openAppSettings()
            } label: {
                Label("Open Settings to Allow Calendar Read Access", systemImage: "gear")
            }
        case .fullAccess:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }

    // MARK: – Helpers

    private func refreshWidgetLastWriteDate() {
        let widgetSourceRaw = LocationSampleSource.widget.rawValue
        var descriptor = FetchDescriptor<LocationSample>(sortBy: [SortDescriptor(\LocationSample.timestamp, order: .reverse)])
        descriptor.fetchLimit = 1
        descriptor.predicate = #Predicate<LocationSample> { sample in
            sample.sourceRaw == widgetSourceRaw
        }
        widgetLastWriteDate = (try? modelContext.fetch(descriptor))?.first?.timestamp
    }

    private func resetAllData() {
        do {
            try dataManager.resetAllData()
            // Allow the bootstrap to re-run on next launch so fresh inference
            // is computed against any newly added data.
            didBootstrapInference = false
        } catch {
            print("Failed to reset data: \(error)")
        }
    }

    private func deleteCloudKitData() {
        isDeletingCloudKitData = true
        Task {
            do {
                try await CloudKitDataResetService.deleteAllUserData()
            } catch {
                await MainActor.run { cloudKitDeleteError = error.localizedDescription }
            }
            await MainActor.run { isDeletingCloudKitData = false }
        }
    }

    private func refreshPermissions() {
        locationStatus = CLLocationManager().authorizationStatus
        photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
    }

    private func requestPhotosAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
            DispatchQueue.main.async { refreshPermissions() }
        }
    }

    private func requestCalendarAccess() {
        let store = EKEventStore()
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { _, _ in
                DispatchQueue.main.async { refreshPermissions() }
            }
        } else {
            store.requestAccess(to: .event) { _, _ in
                DispatchQueue.main.async { refreshPermissions() }
            }
        }
    }

    private func rescanPhotos() {
        isIngestingPhotos = true
        let container = modelContext.container
        Task {
            let ingestor = PhotoSignalIngestor(modelContainer: container, resolver: CLGeocoderCountryResolver())
            _ = await ingestor.ingest(mode: .sequenced)
            await MainActor.run { isIngestingPhotos = false }
        }
    }

    private func rescanCalendar() {
        isIngestingCalendar = true
        let container = modelContext.container
        Task {
            let ingestor = CalendarSignalIngestor(modelContainer: container, resolver: CLGeocoderCountryResolver())
            _ = await ingestor.ingest(mode: .manualFullScan)
            await MainActor.run { isIngestingCalendar = false }
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private var calendarHasReadAccess: Bool {
        calendarStatus == .fullAccess
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var dataStoreLabel: String {
        switch dataStoreStatus {
        case .cloudKit:
            return "iCloud/CloudKit"
        case .local:
            return "Local App storage"
        case .temporary:
            return "Temporary data store (failure mode)"
        }
    }

    private var dataStoreColor: Color {
        switch dataStoreStatus {
        case .temporary:
            return .red
        case .cloudKit, .local:
            return .green
        }
    }

    private var dataStoreStatus: DataStoreStatus {
        let configurations = modelContext.container.configurations
        if configurations.contains(where: { $0.isStoredInMemoryOnly }) {
            return .temporary
        }
        if configurations.contains(where: { $0.cloudKitContainerIdentifier != nil }) {
            return .cloudKit
        }
        return .local
    }

    private var locationStatusText: String {
        switch locationStatus {
        case .authorizedAlways:    return "Always On"
        case .authorizedWhenInUse: return "When In Use"
        case .denied:              return "Denied"
        case .restricted:          return "Restricted"
        case .notDetermined:       return "Not Set"
        @unknown default:          return "Unknown"
        }
    }

    private var locationStatusColor: Color {
        switch locationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return .green
        case .denied, .restricted:                    return .red
        case .notDetermined:                          return .orange
        @unknown default:                             return .secondary
        }
    }

    private var photoStatusText: String {
        switch photoStatus {
        case .authorized:  return "Geo Location Access"
        case .limited:     return "Limited photos"
        case .denied:      return "Denied"
        case .restricted:  return "Restricted"
        case .notDetermined: return "Not Set"
        @unknown default:  return "Unknown"
        }
    }

    private var photoStatusColor: Color {
        switch photoStatus {
        case .authorized:              return .green
        case .limited:                 return .orange
        case .denied, .restricted:     return .red
        case .notDetermined:           return .orange
        @unknown default:              return .secondary
        }
    }

    private var calendarStatusText: String {
        switch calendarStatus {
        case .fullAccess:    return "Read Access"
        case .writeOnly:     return "Write Only"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        case .notDetermined: return "Not Set"
        @unknown default:    return "Unknown"
        }
    }

    private var calendarStatusColor: Color {
        switch calendarStatus {
        case .fullAccess:           return .green
        case .writeOnly:            return .orange
        case .denied, .restricted:  return .red
        case .notDetermined:        return .orange
        @unknown default:           return .secondary
        }
    }

    private var cloudKitDeleteErrorPresented: Binding<Bool> {
        Binding(
            get: { cloudKitDeleteError != nil },
            set: { if !$0 { cloudKitDeleteError = nil } }
        )
    }
}

// MARK: – Profile Edit View

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var passportNationality = ""
    @State private var homeCountry = ""

    private let keychainService = "com.MCCANN.Border"


    private func countryDisplayName(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    private func countryLabel(for code: String) -> String {
        "\(countryDisplayName(for: code)) (\(code))"
    }

    private func selectedLabel(for code: String) -> String {
        code.isEmpty ? "Not set" : countryLabel(for: code)
    }

    var body: some View {
        Form {
            Section {
                Text("This information stays on your device and helps BorderLog personalise your travel tracking — for example, correctly calculating Schengen days for your passport type.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            Section("Passport") {
                Menu {
                    Button("Clear") { passportNationality = "" }
                    ForEach(GeoRegion.allCases) { region in
                        Menu(region.displayName) {
                            ForEach(region.countryCodes, id: \.self) { code in
                                Button(countryLabel(for: code)) { passportNationality = code }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("Nationality")
                        Spacer()
                        Text(selectedLabel(for: passportNationality))
                            .foregroundStyle(passportNationality.isEmpty ? .secondary : .primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Home") {
                Menu {
                    Button("Clear") { homeCountry = "" }
                    ForEach(GeoRegion.allCases) { region in
                        Menu(region.displayName) {
                            ForEach(region.countryCodes, id: \.self) { code in
                                Button(countryLabel(for: code)) { homeCountry = code }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("Home Country")
                        Spacer()
                        Text(selectedLabel(for: homeCountry))
                            .foregroundStyle(homeCountry.isEmpty ? .secondary : .primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Data") {
                HStack {
                    Label("Storage", systemImage: "lock.shield")
                    Spacer()
                    Text("On-device only")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Your Profile")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { loadFromKeychain() }
        .onChange(of: passportNationality) { _, v in save(key: "userPassportNationality", value: v) }
        .onChange(of: homeCountry)         { _, v in save(key: "userHomeCountry",         value: v) }
    }

    private func loadFromKeychain() {
        if let d = KeychainHelper.standard.read(service: keychainService, account: "userPassportNationality"),
           let v = String(data: d, encoding: .utf8) { passportNationality = v }
        if let d = KeychainHelper.standard.read(service: keychainService, account: "userHomeCountry"),
           let v = String(data: d, encoding: .utf8) { homeCountry = v }
    }

    private func save(key: String, value: String) {
        if value.isEmpty {
            KeychainHelper.standard.delete(service: keychainService, account: key)
        } else if let data = value.data(using: .utf8) {
            KeychainHelper.standard.save(data, service: keychainService, account: key)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self, CalendarSignal.self], inMemory: true)
}
