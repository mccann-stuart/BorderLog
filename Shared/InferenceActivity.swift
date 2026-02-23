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
    @Published private(set) var isInferenceRunning = false
    @Published private(set) var photoScanScanned = 0
    @Published private(set) var photoScanTotal = 0
    @Published private(set) var isLocationBatching = false
    @Published private(set) var isGeoLookupPaused = false

    private var photoScanCount = 0
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

    func beginInference() {
        inferenceCount += 1
        isInferenceRunning = true
    }

    func endInference() {
        inferenceCount = max(0, inferenceCount - 1)
        isInferenceRunning = inferenceCount > 0
    }
}
