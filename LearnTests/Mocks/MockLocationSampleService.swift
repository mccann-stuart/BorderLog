import Foundation
import SwiftData
@testable import Learn

@MainActor
class MockLocationSampleService: LocationSampleService {
    var captureAndStoreBurstErrorToThrow: Error?
    var captureAndStoreBurstDidCallCount = 0
    var captureAndStoreBurstResult: LocationSample?
    var captureAndStoreBurstModelContext: ModelContext?
    var captureAndStoreBurstSource: LocationSampleSource?

    override func captureAndStoreBurst(
        source: LocationSampleSource,
        modelContext: ModelContext,
        resolver: CountryResolving? = nil,
        maxSamples: Int = 6,
        maxDuration: TimeInterval = 8,
        maxSampleAge: TimeInterval = 120
    ) async throws -> LocationSample? {
        captureAndStoreBurstDidCallCount += 1
        captureAndStoreBurstSource = source
        captureAndStoreBurstModelContext = modelContext

        if let error = captureAndStoreBurstErrorToThrow {
            throw error
        }
        return captureAndStoreBurstResult
    }
}
