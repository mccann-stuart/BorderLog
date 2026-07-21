import re

def main():
    with open('SettingsView.swift', 'r') as f:
        content = f.read()

    # Step 1: Replace body block

    new_body = """    var body: some View {
        Form {
            SettingsProfileSection()

            SettingsPrivacySection(requireBiometrics: $requireBiometrics)

            SettingsCloudKitSection(
                cloudKitSyncEnabled: $cloudKitSyncEnabled,
                isConfirmingCloudKitDelete: $isConfirmingCloudKitDelete,
                isDeletingCloudKitData: isDeletingCloudKitData
            )

            SettingsDataSourcesSection(
                locationStatus: locationStatus,
                locationStatusText: locationStatusText,
                locationStatusColor: locationStatusColor,
                widgetLastWriteDate: widgetLastWriteDate,
                photoStatus: photoStatus,
                photoStatusText: photoStatusText,
                photoStatusColor: photoStatusColor,
                isIngestingPhotos: isIngestingPhotos,
                calendarStatus: calendarStatus,
                calendarStatusText: calendarStatusText,
                calendarStatusColor: calendarStatusColor,
                calendarHasReadAccess: calendarHasReadAccess,
                calendarSelection: $calendarSelection,
                isIngestingCalendar: isIngestingCalendar,
                dataStoreLabel: dataStoreLabel,
                dataStoreColor: dataStoreColor,
                requestLocationAccess: {
                    locationService.requestAuthorizationIfNeeded()
                    refreshPermissions()
                },
                requestPhotosAccess: requestPhotosAccess,
                requestCalendarAccess: requestCalendarAccess,
                openSettings: openAppSettings,
                rescanPhotos: rescanPhotos,
                rescanCalendar: rescanCalendar
            )

            SettingsSetupSection(
                hasCompletedOnboarding: $hasCompletedOnboarding,
                hasPromptedLocation: $hasPromptedLocation,
                hasPromptedPhotos: $hasPromptedPhotos,
                hasPromptedCalendar: $hasPromptedCalendar
            )

            SettingsDataManagementSection(isConfirmingReset: $isConfirmingReset)

#if DEBUG
            SettingsDebugSection(
                isPreparingDebugExport: isPreparingDebugExport,
                exportDebugDataStore: exportDebugDataStore
            )
#endif

            SettingsAboutSection(appVersionString: appVersionString)

            SettingsMapDisplaySection(usePolygonMapView: $usePolygonMapView)

            SettingsConfigurationSection(
                countryDayCountingModeRaw: $countryDayCountingModeRaw,
                showSchengenDashboardSection: $showSchengenDashboardSection
            )
        }
        .scrollContentBackground(.hidden)"""

    # We need to replace from `    var body: some View {` down to `.scrollContentBackground(.hidden)`
    # This matches exactly our intended body block replacement.

    body_pattern = re.compile(r'    var body: some View \{(.*?)\.scrollContentBackground\(\.hidden\)', re.DOTALL)

    if not body_pattern.search(content):
        print("Could not find body block to replace!")
        return

    content = body_pattern.sub(new_body, content)

    # Step 2: Remove helpers

    helpers_to_remove = [
        # cloudKitSection
        re.compile(r'    // MARK: – CloudKit Section.*?    // MARK: – Smart Location Row\n', re.DOTALL),
        # locationActionRow, openSettingsButton
        re.compile(r'    // MARK: – Smart Location Row.*?    // MARK: – Smart Photos Row\n', re.DOTALL),
        # photoActionRow
        re.compile(r'    // MARK: – Smart Photos Row.*?    // MARK: – Smart Calendar Row\n', re.DOTALL),
        # calendarActionRow
        re.compile(r'    // MARK: – Smart Calendar Row.*?    // MARK: – Helpers\n', re.DOTALL)
    ]

    for pattern in helpers_to_remove:
        content = pattern.sub('    // MARK: – Helpers\n', content, count=1)

    # Let's fix potential multiple `// MARK: – Helpers`
    while '    // MARK: – Helpers\n    // MARK: – Helpers' in content:
        content = content.replace('    // MARK: – Helpers\n    // MARK: – Helpers', '    // MARK: – Helpers')

    # Step 3: Append the new structs at the end of the file, just before `// MARK: – Profile Edit View`
    # Or just after SettingsView finishes

    structs = """
struct SettingsProfileSection: View {
    var body: some View {
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
    }
}

struct SettingsPrivacySection: View {
    @Binding var requireBiometrics: Bool

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Local-First Storage", systemImage: "lock.shield.fill")
                    .font(.headline)
                Text("Your travel data is stored on this device. BorderLog does not run analytics, tracking, or app-owned user-data servers.")
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
    }
}

struct SettingsCloudKitSection: View {
    @Binding var cloudKitSyncEnabled: Bool
    @Binding var isConfirmingCloudKitDelete: Bool
    let isDeletingCloudKitData: Bool

    var body: some View {
        if AppConfig.isCloudKitFeatureEnabled {
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
    }
}

struct SettingsLocationActionRow: View {
    let locationStatus: CLAuthorizationStatus
    let requestAuthorization: () -> Void
    let openSettings: () -> Void

    var body: some View {
        switch locationStatus {
        case .notDetermined:
            Button {
                requestAuthorization()
            } label: {
                Label("Request Location Access", systemImage: "hand.raised")
            }
        case .denied, .restricted:
            Button {
                openSettings()
            } label: {
                Label("Open Settings to Enable Location", systemImage: "gear")
            }
        case .authorizedWhenInUse, .authorizedAlways:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }
}

struct SettingsPhotoActionRow: View {
    let photoStatus: PHAuthorizationStatus
    let requestAccess: () -> Void
    let openSettings: () -> Void

    var body: some View {
        switch photoStatus {
        case .notDetermined:
            Button {
                requestAccess()
            } label: {
                Label("Request Photos Access", systemImage: "hand.raised")
            }
        case .denied, .restricted:
            Button {
                openSettings()
            } label: {
                Label("Open Settings to Enable Photos", systemImage: "gear")
            }
        case .authorized, .limited:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }
}

struct SettingsCalendarActionRow: View {
    let calendarStatus: EKAuthorizationStatus
    let requestAccess: () -> Void
    let openSettings: () -> Void

    var body: some View {
        switch calendarStatus {
        case .notDetermined:
            Button {
                requestAccess()
            } label: {
                Label("Request Calendar Access", systemImage: "hand.raised")
            }
        case .denied, .restricted:
            Button {
                openSettings()
            } label: {
                Label("Open Settings to Enable Calendar", systemImage: "gear")
            }
        case .writeOnly:
            Button {
                openSettings()
            } label: {
                Label("Open Settings to Allow Calendar Read Access", systemImage: "gear")
            }
        case .fullAccess:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }
}

struct SettingsDataSourcesSection: View {
    let locationStatus: CLAuthorizationStatus
    let locationStatusText: String
    let locationStatusColor: Color
    let widgetLastWriteDate: Date?

    let photoStatus: PHAuthorizationStatus
    let photoStatusText: String
    let photoStatusColor: Color
    let isIngestingPhotos: Bool

    let calendarStatus: EKAuthorizationStatus
    let calendarStatusText: String
    let calendarStatusColor: Color
    let calendarHasReadAccess: Bool
    @Binding var calendarSelection: CalendarSourceSelection
    let isIngestingCalendar: Bool

    let dataStoreLabel: String
    let dataStoreColor: Color

    let requestLocationAccess: () -> Void
    let requestPhotosAccess: () -> Void
    let requestCalendarAccess: () -> Void
    let openSettings: () -> Void
    let rescanPhotos: () -> Void
    let rescanCalendar: () -> Void

    var body: some View {
        Section {
            // Location
            HStack {
                Label("Location", systemImage: "location.fill")
                Spacer()
                Text(locationStatusText)
                    .foregroundStyle(locationStatusColor)
                    .font(.subheadline)
            }

            SettingsLocationActionRow(
                locationStatus: locationStatus,
                requestAuthorization: requestLocationAccess,
                openSettings: openSettings
            )

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

            SettingsPhotoActionRow(
                photoStatus: photoStatus,
                requestAccess: requestPhotosAccess,
                openSettings: openSettings
            )

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

            SettingsCalendarActionRow(
                calendarStatus: calendarStatus,
                requestAccess: requestCalendarAccess,
                openSettings: openSettings
            )

            if calendarHasReadAccess {
                NavigationLink {
                    CalendarSourcesSettingsView(selection: $calendarSelection)
                } label: {
                    HStack {
                        Label("Calendars", systemImage: "calendar.badge.checkmark")
                        Spacer()
                        Text(calendarSelection.summary)
                            .foregroundStyle(.secondary)
                    }
                }

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
            Text("Location and read-only events from your selected calendars help determine which country you were in each day. Verified photo metadata is shown only as non-scoring review context. BorderLog stores this data locally and may use Apple system services such as MapKit geocoding to resolve countries.")
        }
    }
}

struct SettingsSetupSection: View {
    @Binding var hasCompletedOnboarding: Bool
    @Binding var hasPromptedLocation: Bool
    @Binding var hasPromptedPhotos: Bool
    @Binding var hasPromptedCalendar: Bool

    var body: some View {
        Section {
            Button {
                hasCompletedOnboarding = false
                hasPromptedLocation = false
                hasPromptedPhotos = false
                hasPromptedCalendar = false
            } label: {
                Label("Re-Launch Setup", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Setup")
        }
    }
}

struct SettingsDataManagementSection: View {
    @Binding var isConfirmingReset: Bool

    var body: some View {
        Section {
            Button("Reset All Data", role: .destructive) {
                isConfirmingReset = true
            }
        } header: {
            Text("Data Management")
        } footer: {
            Text("Permanently deletes local travel data, profile values, and pending widget samples stored on this device.")
        }
    }
}

#if DEBUG
struct SettingsDebugSection: View {
    let isPreparingDebugExport: Bool
    let exportDebugDataStore: () -> Void

    var body: some View {
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
            Text("Exports a full-fidelity JSON snapshot for internal debugging, including raw coordinates, event identifiers, titles, asset hashes, and local user identifiers. Do not share this file externally unless you have reviewed it.")
        }
    }
}
#endif

struct SettingsAboutSection: View {
    let appVersionString: String

    var body: some View {
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

            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
        } header: {
            Text("About BorderLog")
        }
    }
}

struct SettingsMapDisplaySection: View {
    @Binding var usePolygonMapView: Bool

    var body: some View {
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
    }
}

struct SettingsConfigurationSection: View {
    @Binding var countryDayCountingModeRaw: String
    @Binding var showSchengenDashboardSection: Bool

    var body: some View {
        Section {
            Picker("Day Counting", selection: $countryDayCountingModeRaw) {
                ForEach(CountryDayCountingMode.allCases) { mode in
                    Text(mode.label).tag(mode.rawValue)
                }
            }

            Toggle(isOn: $showSchengenDashboardSection) {
                Label("Schengen Zone", systemImage: "map")
            }
        } header: {
            Text("Configuration")
        } footer: {
            Text("Double Count Days counts every resolved country for travel days where immigration-style rules count both entry and exit dates. Schengen country list is built-in and updates automatically.")
        }
    }
}

"""

    # Let's place it right before `// MARK: – Profile Edit View`
    replace_marker = "// MARK: – Profile Edit View"
    if replace_marker in content:
        content = content.replace(replace_marker, structs + "\n" + replace_marker)
    else:
        content += "\n" + structs

    with open('SettingsView.swift', 'w') as f:
        f.write(content)

    print("Success")

if __name__ == "__main__":
    main()
