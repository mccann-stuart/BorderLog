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
import os

struct SettingsView: View {
    private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "SettingsView")

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
    @State private var ingestionError: String?
    @State private var locationService = LocationSampleService()
    @State private var widgetLastWriteDate: Date?
    @State private var isPreparingDebugExport = false
    @State private var isPresentingDebugExport = false
    @State private var debugExportError: String?
    @State private var debugExportDocument = DebugDataStoreExportDocument(data: Data())
    @State private var debugExportDefaultFilename = "borderlog-debug-export"
    @AppStorage("didBootstrapInference") private var didBootstrapInference = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasPromptedLocation") private var hasPromptedLocation = false
    @AppStorage("hasPromptedPhotos") private var hasPromptedPhotos = false
    @AppStorage("hasPromptedCalendar") private var hasPromptedCalendar = false
    @AppStorage("usePolygonMapView") private var usePolygonMapView = true
    @AppStorage("showSchengenDashboardSection") private var showSchengenDashboardSection = true
    @AppStorage("cloudKitSyncEnabled", store: AppConfig.sharedDefaults) private var cloudKitSyncEnabled = false
    @AppStorage("requireBiometrics") private var requireBiometrics = false

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

                    Toggle(isOn: $requireBiometrics) {
                        Label("Require Face ID / Touch ID", systemImage: "faceid")
                    }
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
                    Text("Location, photo metadata, and read-only calendar events are used to automatically determine which country you were in each day. All processing happens on your device. No data is stored on any server or outside the app.")
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

                Section {
                    Button {
                        exportDebugDataStore()
                    } label: {
                        HStack {
                            Label(
                                isPreparingDebugExport ? "Preparing Export…" : "Export Debug Data Store",
                                systemImage: isPreparingDebugExport ? "arrow.triangle.2.circlepath" : "square.and.arrow.up"
                            )
                            if isPreparingDebugExport {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isPreparingDebugExport)
                } header: {
                    Text("Debug Export")
                } footer: {
                    Text("Exports a full-fidelity JSON snapshot for internal debugging, including raw coordinates, event identifiers, titles, asset hashes, and local user identifiers.")
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
                    Text("Schengen country list is built-in and updates automatically. This toggle controls visibility of the 'Schengen 90 stays valid for a rolling 180 days' card on Dashboard.")
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
            .alert("Ingestion failed", isPresented: ingestionErrorPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(ingestionError ?? "Unknown error.")
            }
            .alert("Unable to export debug data", isPresented: debugExportErrorPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(debugExportError ?? "Unknown error.")
            }
            .fileExporter(
                isPresented: $isPresentingDebugExport,
                document: debugExportDocument,
                contentTypes: DebugDataStoreExportDocument.readableContentTypes,
                defaultFilename: debugExportDefaultFilename
            ) { result in
                if case .failure(let error) = result {
                    Self.logger.error("Debug export file handoff failed: \(error, privacy: .private)")
                    debugExportError = "Failed to hand off the debug export file. Please try again."
                }
            }
            .onAppear {
                refreshPermissions()
                refreshWidgetLastWriteDate()
            }
    }

    // MARK: – Smart Location Row

    private func openSettingsButton(title: String) -> some View {
        Button {
            openAppSettings()
        } label: {
            Label(title, systemImage: "gear")
        }
    }

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
            openSettingsButton(title: "Open Settings to Enable Location")
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
            openSettingsButton(title: "Open Settings to Enable Photos")
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
            openSettingsButton(title: "Open Settings to Enable Calendar")
        case .writeOnly:
            openSettingsButton(title: "Open Settings to Allow Calendar Read Access")
        case .fullAccess:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }

    // MARK: – Helpers

    private func refreshWidgetLastWriteDate() {
        widgetLastWriteDate = latestWidgetWriteDate()
    }

    private func latestWidgetWriteDate() -> Date? {
        let widgetSourceRaw = LocationSampleSource.widget.rawValue
        var descriptor = FetchDescriptor<LocationSample>(sortBy: [SortDescriptor(\LocationSample.timestamp, order: .reverse)])
        descriptor.fetchLimit = 1
        descriptor.predicate = #Predicate<LocationSample> { sample in
            sample.sourceRaw == widgetSourceRaw
        }
        return (try? modelContext.fetch(descriptor))?.first?.timestamp
    }

    private func resetAllData() {
        do {
            try dataManager.resetAllData()
            // Allow the bootstrap to re-run on next launch so fresh inference
            // is computed against any newly added data.
            didBootstrapInference = false
        } catch {
            Self.logger.error("Failed to reset data: \(error, privacy: .private)")
        }
    }

    private func deleteCloudKitData() {
        isDeletingCloudKitData = true
        Task {
            do {
                try await CloudKitDataResetService.deleteAllUserData()
            } catch {
                Self.logger.error("Failed to delete CloudKit data: \(error, privacy: .private)")
                await MainActor.run { cloudKitDeleteError = "Failed to delete iCloud data. Please try again." }
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
        Task { @MainActor in
            defer { isIngestingPhotos = false }
            do {
                let ingestor = PhotoSignalIngestor(modelContainer: container, resolver: CLGeocoderCountryResolver())
                _ = try await ingestor.ingest(mode: .sequenced)
            } catch {
                Self.logger.error("Failed to ingest photos: \(error, privacy: .private)")
                ingestionError = "Failed to scan photos. Please try again."
            }
        }
    }

    private func rescanCalendar() {
        isIngestingCalendar = true
        let container = modelContext.container
        Task { @MainActor in
            defer { isIngestingCalendar = false }
            do {
                let ingestor = CalendarSignalIngestor(modelContainer: container, resolver: CLGeocoderCountryResolver())
                _ = try await ingestor.ingest(mode: .manualFullScan)
            } catch {
                Self.logger.error("Failed to ingest calendar: \(error, privacy: .private)")
                ingestionError = "Failed to scan calendar. Please try again."
            }
        }
    }

    private func exportDebugDataStore() {
        isPreparingDebugExport = true
        debugExportError = nil

        let exportedAt = Date()
        let runtimeContext = makeDebugExportContext(exportedAt: exportedAt)
        let container = modelContext.container

        Task {
            do {
                let service = DebugDataStoreExportService(modelContainer: container)
                let data = try await service.exportJSON(context: runtimeContext)
                await MainActor.run {
                    debugExportDocument = DebugDataStoreExportDocument(data: data)
                    debugExportDefaultFilename = Self.debugExportFilename(for: exportedAt)
                    isPresentingDebugExport = true
                    isPreparingDebugExport = false
                }
            } catch {
                Self.logger.error("Failed to export debug data store: \(error, privacy: .private)")
                await MainActor.run {
                    isPreparingDebugExport = false
                    debugExportError = "Failed to export debug data. Please try again."
                }
            }
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
        "\(appVersion) (\(appBuild))"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var dataStoreLabel: String {
        switch dataStoreStatus {
        case .cloudKit:
            return "iCloud/CloudKit"
        case .local:
            return "Local App storage"
        case .temporary:
            return "Not saving (Error)"
        }
    }

    private var dataStoreModeCode: String {
        switch dataStoreStatus {
        case .cloudKit:
            return "cloudKit"
        case .local:
            return "local"
        case .temporary:
            return "temporary"
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

    private func makeDebugExportContext(exportedAt: Date) -> DebugExportRuntimeContext {
        let currentLocationStatus = CLLocationManager().authorizationStatus
        let currentPhotoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let currentCalendarStatus = EKEventStore.authorizationStatus(for: .event)
        let pendingSnapshots = PendingLocationSnapshot.dequeueAll(from: AppConfig.sharedDefaults, clearAfter: false)
            .map {
                DebugExportPendingLocationSnapshot(
                    timestamp: $0.timestamp,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    accuracyMeters: $0.accuracyMeters,
                    sourceRaw: $0.sourceRaw,
                    timeZoneId: $0.timeZoneId,
                    dayKey: $0.dayKey,
                    countryCode: $0.countryCode,
                    countryName: $0.countryName
                )
            }
        let latestWidgetWriteDate = latestWidgetWriteDate()
        widgetLastWriteDate = latestWidgetWriteDate

        let metadata = DebugExportMetadata(
            exportedAt: exportedAt,
            appVersion: appVersion,
            appBuild: appBuild,
            bundleIdentifier: Bundle.main.bundleIdentifier,
            deviceModelCategory: deviceModelCategory,
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            localeIdentifier: Locale.autoupdatingCurrent.identifier,
            currentTimeZoneId: TimeZone.current.identifier,
            appVariantFlags: DebugExportAppVariantFlags(
                cloudKitFeatureEnabled: AppConfig.isCloudKitFeatureEnabled,
                appleSignInEnabled: AuthenticationManager.isAppleSignInEnabled,
                appGroupAvailable: AppConfig.isAppGroupAvailable
            )
        )

        let appState = DebugExportAppState(
            hasCompletedOnboarding: hasCompletedOnboarding,
            didBootstrapInference: didBootstrapInference,
            hasPromptedLocation: hasPromptedLocation,
            hasPromptedPhotos: hasPromptedPhotos,
            hasPromptedCalendar: hasPromptedCalendar,
            usePolygonMapView: usePolygonMapView,
            showSchengenDashboardSection: showSchengenDashboardSection,
            cloudKitSyncEnabled: cloudKitSyncEnabled,
            requireBiometrics: requireBiometrics,
            locationPermission: locationPermissionStatus(for: currentLocationStatus),
            photoPermission: photoPermissionStatus(for: currentPhotoStatus),
            calendarPermission: calendarPermissionStatus(for: currentCalendarStatus),
            dataStoreMode: dataStoreModeCode,
            appGroupAvailable: AppConfig.isAppGroupAvailable,
            cloudKitFeatureEnabled: AppConfig.isCloudKitFeatureEnabled,
            currentStoreEpoch: ModelContainerProvider.currentStoreEpochForTests,
            storedStoreEpoch: AppConfig.sharedDefaults.integer(forKey: ModelContainerProvider.storeEpochKeyForTests),
            widgetLastWriteDate: latestWidgetWriteDate,
            pendingWidgetSnapshotCount: pendingSnapshots.count
        )

        let userData = DebugExportUserData(
            passportNationality: readKeychainString(account: "userPassportNationality"),
            homeCountry: readKeychainString(account: "userHomeCountry"),
            appleUserId: readKeychainString(account: "appleUserId"),
            appleSignInEnabled: AuthenticationManager.isAppleSignInEnabled
        )

        return DebugExportRuntimeContext(
            metadata: metadata,
            appState: appState,
            userData: userData,
            pendingLocationSnapshots: pendingSnapshots
        )
    }

    private func readKeychainString(account: String) -> String? {
        guard let data = KeychainHelper.standard.read(service: "com.MCCANN.Border", account: account),
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func locationPermissionStatus(for status: CLAuthorizationStatus) -> DebugExportPermissionStatus {
        DebugExportPermissionStatus(rawValue: Int(status.rawValue), label: locationStatusLabel(for: status))
    }

    private func photoPermissionStatus(for status: PHAuthorizationStatus) -> DebugExportPermissionStatus {
        DebugExportPermissionStatus(rawValue: Int(status.rawValue), label: photoStatusLabel(for: status))
    }

    private func calendarPermissionStatus(for status: EKAuthorizationStatus) -> DebugExportPermissionStatus {
        DebugExportPermissionStatus(rawValue: Int(status.rawValue), label: calendarStatusLabel(for: status))
    }

    private var deviceModelCategory: String {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return "phone"
        case .pad:
            return "pad"
        case .mac:
            return "mac"
        case .tv:
            return "tv"
        case .vision:
            return "vision"
        case .carPlay:
            return "carPlay"
        case .unspecified:
            return "unspecified"
        @unknown default:
            return "unknown"
        }
    }

    private static func debugExportFilename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "borderlog-debug-export-\(formatter.string(from: date))"
    }

    private var cloudKitDeleteErrorPresented: Binding<Bool> {
        Binding(
            get: { cloudKitDeleteError != nil },
            set: { if !$0 { cloudKitDeleteError = nil } }
        )
    }

    private var ingestionErrorPresented: Binding<Bool> {
        Binding(
            get: { ingestionError != nil },
            set: { if !$0 { ingestionError = nil } }
        )
    }

    private var debugExportErrorPresented: Binding<Bool> {
        Binding(
            get: { debugExportError != nil },
            set: { if !$0 { debugExportError = nil } }
        )
    }

    private func locationStatusLabel(for status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways:    return "Always On"
        case .authorizedWhenInUse: return "When In Use"
        case .denied:              return "Denied"
        case .restricted:          return "Restricted"
        case .notDetermined:       return "Not Set"
        @unknown default:          return "Unknown"
        }
    }

    private func photoStatusLabel(for status: PHAuthorizationStatus) -> String {
        switch status {
        case .authorized:    return "Geo Location Access"
        case .limited:       return "Limited photos"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        case .notDetermined: return "Not Set"
        @unknown default:    return "Unknown"
        }
    }

    private func calendarStatusLabel(for status: EKAuthorizationStatus) -> String {
        switch status {
        case .fullAccess:    return "Read Access"
        case .writeOnly:     return "Write Only"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        case .notDetermined: return "Not Set"
        @unknown default:    return "Unknown"
        }
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
        .modelContainer(for: [Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, PresenceDay.self, PhotoIngestState.self, CountryConfig.self, CalendarSignal.self], inMemory: true)
}
