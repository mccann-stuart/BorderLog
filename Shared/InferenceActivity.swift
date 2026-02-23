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

    private var photoScanCount = 0
    private var inferenceCount = 0

    private init() {}

    func beginPhotoScan() {
        photoScanCount += 1
        isPhotoScanning = true
    }

    func endPhotoScan() {
        photoScanCount = max(0, photoScanCount - 1)
        isPhotoScanning = photoScanCount > 0
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
