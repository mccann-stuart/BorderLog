//
//  InferenceActivity.swift
//  Learn
//

import Combine
import Foundation

@MainActor
final class InferenceActivity: ObservableObject {
    static let shared = InferenceActivity()

    @Published private(set) var isPhotoScanning = false
    @Published private(set) var isCalendarScanning = false
    @Published private(set) var isInferenceRunning = false
    @Published private(set) var photoScanScanned = 0
    @Published private(set) var photoScanTotal = 0
    @Published private(set) var calendarScanScanned = 0
    @Published private(set) var calendarScanTotal = 0
    @Published private(set) var isLocationBatching = false
    @Published private(set) var isGeoLookupPaused = false
    @Published private(set) var inferenceProgress = 0
    @Published private(set) var inferenceTotal = 0

    private var photoScanCount = 0
    private var calendarScanCount = 0
    private var inferenceCount = 0
    private var locationBatchCount = 0
    private var geoLookupHoldCount = 0

    private init() {}

    func beginPhotoScan(totalAssets: Int) {
        let wasScanning = photoScanCount > 0
        photoScanCount += 1
        isPhotoScanning = true
        if !wasScanning {
            photoScanTotal = max(0, totalAssets)
            photoScanScanned = 0
        }
    }

    func updatePhotoScanProgress(scannedAssets: Int) {
        let clampedScanned = max(0, scannedAssets)
        if photoScanTotal > 0 {
            photoScanScanned = min(clampedScanned, photoScanTotal)
        } else {
            photoScanScanned = clampedScanned
        }
    }

    func endPhotoScan() {
        photoScanCount = max(0, photoScanCount - 1)
        isPhotoScanning = photoScanCount > 0
        if !isPhotoScanning {
            photoScanScanned = 0
            photoScanTotal = 0
        }
    }

    func beginCalendarScan(totalEvents: Int) {
        let wasScanning = calendarScanCount > 0
        calendarScanCount += 1
        isCalendarScanning = true
        if !wasScanning {
            calendarScanTotal = max(0, totalEvents)
            calendarScanScanned = 0
        }
    }

    func updateCalendarScanProgress(scannedEvents: Int) {
        let clampedScanned = max(0, scannedEvents)
        if calendarScanTotal > 0 {
            calendarScanScanned = min(clampedScanned, calendarScanTotal)
        } else {
            calendarScanScanned = clampedScanned
        }
    }

    func endCalendarScan() {
        calendarScanCount = max(0, calendarScanCount - 1)
        isCalendarScanning = calendarScanCount > 0
        if !isCalendarScanning {
            calendarScanScanned = 0
            calendarScanTotal = 0
        }
    }

    func beginLocationBatch() {
        locationBatchCount += 1
        isLocationBatching = locationBatchCount > 0
    }

    func endLocationBatch() {
        locationBatchCount = max(0, locationBatchCount - 1)
        isLocationBatching = locationBatchCount > 0
    }

    func beginGeoLookupHold() {
        geoLookupHoldCount += 1
        isGeoLookupPaused = geoLookupHoldCount > 0
    }

    func endGeoLookupHold() {
        geoLookupHoldCount = max(0, geoLookupHoldCount - 1)
        isGeoLookupPaused = geoLookupHoldCount > 0
    }

    func beginInference(totalDays: Int) {
        inferenceCount += 1
        isInferenceRunning = true
        inferenceTotal = max(0, totalDays)
        inferenceProgress = 0
    }

    func updateInferenceProgress(processedDays: Int) {
        let clampedProcessed = max(0, processedDays)
        if inferenceTotal > 0 {
            inferenceProgress = min(clampedProcessed, inferenceTotal)
        } else {
            inferenceProgress = clampedProcessed
        }
    }

    func endInference() {
        inferenceCount = max(0, inferenceCount - 1)
        isInferenceRunning = inferenceCount > 0
        if !isInferenceRunning {
            inferenceProgress = 0
            inferenceTotal = 0
        }
    }
}
