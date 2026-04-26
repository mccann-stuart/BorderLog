//
//  PermissionsRequestView.swift
//  Learn
//

import SwiftUI
import CoreLocation
import Photos
import EventKit

struct PermissionsRequestView: View {
    var onComplete: () -> Void
    
    @State private var locationStatus: CLAuthorizationStatus = CLLocationManager().authorizationStatus
    @State private var photoStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var calendarStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @State private var locationService = LocationSampleService()
    @State private var locationStatusRefreshTask: Task<Void, Never>?
    
    // Track if permissions have been prompted to hide the UI block once completed
    @AppStorage("hasPromptedLocation") private var hasPromptedLocation = false
    @AppStorage("hasPromptedPhotos") private var hasPromptedPhotos = false
    @AppStorage("hasPromptedCalendar") private var hasPromptedCalendar = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                
                VStack(spacing: 8) {
                    Text("Permissions")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("BorderLog works best when it can infer your location automatically. These are optional and can be changed later in Settings.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                VStack(spacing: 24) {
                    if shouldShowLocationCard {
                        PermissionCard(
                            icon: "location.fill",
                            title: "Location Access",
                            description: "Provides opportunistic location fixes via the Home Screen widget.",
                            buttonTitle: locationButtonTitle
                        ) {
                            requestLocationAccess()
                        }
                    }
                    
                    if shouldShowPhotoCard {
                        PermissionCard(
                            icon: "photo.fill",
                            title: "Photos Access",
                            description: "Reads photo location metadata to determine the countries you visited.",
                            buttonTitle: photoButtonTitle
                        ) {
                            requestPhotosAccess()
                        }
                    }

                    if shouldShowCalendarCard {
                        PermissionCard(
                            icon: "calendar",
                            title: "Calendar Access",
                            description: "Reads flight events (e.g. from Flighty) to infer travel dates. BorderLog never writes to your calendar.",
                            buttonTitle: calendarButtonTitle
                        ) {
                            requestCalendarAccess()
                        }
                    }
                    
                    if !shouldShowLocationCard && !shouldShowPhotoCard && !shouldShowCalendarCard {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.green)
                            Text("All set!")
                                .font(.headline)
                        }
                        .padding()
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .animation(.easeInOut, value: locationStatus)
                .animation(.easeInOut, value: photoStatus)
                .animation(.easeInOut, value: calendarStatus)
                
                Button {
                    onComplete()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
        .onAppear {
            refreshStatus()
        }
        .onDisappear {
            locationStatusRefreshTask?.cancel()
        }
    }
    
    private func refreshStatus() {
        locationStatus = CLLocationManager().authorizationStatus
        photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
    }

    private var shouldShowLocationCard: Bool {
        switch locationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return false
        default:
            return true
        }
    }

    private var shouldShowPhotoCard: Bool {
        photoStatus != .authorized && photoStatus != .limited
    }

    private var shouldShowCalendarCard: Bool {
        calendarStatus != .fullAccess
    }

    private var locationButtonTitle: String {
        switch locationStatus {
        case .denied, .restricted:
            return "Open Settings"
        default:
            return "Allow Location"
        }
    }

    private var photoButtonTitle: String {
        switch photoStatus {
        case .denied, .restricted:
            return "Open Settings"
        default:
            return "Allow Photos"
        }
    }

    private var calendarButtonTitle: String {
        switch calendarStatus {
        case .denied, .restricted, .writeOnly:
            return "Open Settings"
        default:
            return "Allow Calendar"
        }
    }

    private func requestLocationAccess() {
        switch locationStatus {
        case .denied, .restricted:
            openAppSettings()
        case .authorizedAlways, .authorizedWhenInUse:
            refreshStatus()
        default:
            locationService.requestAuthorizationIfNeeded()
            pollLocationAuthorizationResolution()
        }
    }

    private func requestPhotosAccess() {
        switch photoStatus {
        case .denied, .restricted:
            openAppSettings()
        default:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
                DispatchQueue.main.async {
                    hasPromptedPhotos = true
                    refreshStatus()
                }
            }
        }
    }

    private func requestCalendarAccess() {
        switch calendarStatus {
        case .denied, .restricted, .writeOnly:
            openAppSettings()
        default:
            let store = EKEventStore()
            if #available(iOS 17.0, *) {
                store.requestFullAccessToEvents { _, _ in
                    DispatchQueue.main.async {
                        hasPromptedCalendar = true
                        refreshStatus()
                    }
                }
            } else {
                store.requestAccess(to: .event) { _, _ in
                    DispatchQueue.main.async {
                        hasPromptedCalendar = true
                        refreshStatus()
                    }
                }
            }
        }
    }

    private func pollLocationAuthorizationResolution() {
        locationStatusRefreshTask?.cancel()
        locationStatusRefreshTask = Task { @MainActor in
            for _ in 0..<50 {
                refreshStatus()
                if locationStatus != .notDetermined {
                    hasPromptedLocation = true
                    return
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            refreshStatus()
            if locationStatus != .notDetermined {
                hasPromptedLocation = true
            }
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

private struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let buttonTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Button(action: action) {
                Text(buttonTitle)
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    PermissionsRequestView(onComplete: {})
}
