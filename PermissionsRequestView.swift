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
    
    // Track if permissions have been prompted to hide the UI block once completed
    @AppStorage("hasPromptedLocation") private var hasPromptedLocation = false
    @AppStorage("hasPromptedPhotos") private var hasPromptedPhotos = false
    @AppStorage("hasPromptedCalendar") private var hasPromptedCalendar = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Header Image
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            // Text
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
            
            // Permission Cards
            VStack(spacing: 24) {
                if !hasPromptedLocation || locationStatus == .notDetermined {
                    PermissionCard(
                        icon: "location.fill",
                        title: "Location Access",
                        description: "Provides opportunistic location fixes via the Home Screen widget.",
                        buttonTitle: "Allow Location"
                    ) {
                        locationService.requestAuthorizationIfNeeded()
                        hasPromptedLocation = true
                        refreshStatus()
                    }
                }
                
                if !hasPromptedPhotos || photoStatus == .notDetermined {
                    PermissionCard(
                        icon: "photo.fill",
                        title: "Photos Access",
                        description: "Reads photo location metadata to determine the countries you visited.",
                        buttonTitle: "Allow Photos"
                    ) {
                        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
                            DispatchQueue.main.async {
                                hasPromptedPhotos = true
                                refreshStatus()
                            }
                        }
                    }
                }

                if !hasPromptedCalendar || calendarStatus == .notDetermined {
                    PermissionCard(
                        icon: "calendar",
                        title: "Calendar Access",
                        description: "Scans for flight events (e.g. from Flighty) to infer travel dates.",
                        buttonTitle: "Allow Calendar"
                    ) {
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
                
                if (hasPromptedLocation || locationStatus != .notDetermined) &&
                   (hasPromptedPhotos || photoStatus != .notDetermined) &&
                   (hasPromptedCalendar || calendarStatus != .notDetermined) {
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
            
            Spacer()
            
            // Navigation
            VStack(spacing: 16) {
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
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .onAppear {
            refreshStatus()
        }
    }
    
    private func refreshStatus() {
        locationStatus = CLLocationManager().authorizationStatus
        photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
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
