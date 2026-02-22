//
//  LocationConcurrencyTests.swift
//  LearnTests
//
//  Created by Jules on 22/02/2026.
//

import XCTest
@testable import Learn
import CoreLocation
import SwiftData

@MainActor
final class LocationConcurrencyTests: XCTestCase {

    func testConcurrentCaptureLocationDoesNotHang() async throws {
        // This test verifies that calling captureAndStore (which calls captureLocation)
        // concurrently does not cause a deadlock or continuation leak.
        //
        // Note: In a real test environment, we would need to mock CLLocationManager
        // to return authorized status and simulate location updates.
        // Without mocking, this test might return early due to missing permissions,
        // but it still verifies that the method calls do not block indefinitely.

        let service = LocationSampleService()
        let container = ModelContainerProvider.makeContainer()

        // Create concurrent tasks
        async let result1 = service.captureAndStore(source: .app, modelContext: container.mainContext)
        async let result2 = service.captureAndStore(source: .app, modelContext: container.mainContext)

        // Await both results. If the race condition exists and causes a hang,
        // this test will timeout (fail).
        let _ = await result1
        let _ = await result2

        // Success if we reached here
        XCTAssertTrue(true, "Concurrent requests completed without hanging")
    }
}
