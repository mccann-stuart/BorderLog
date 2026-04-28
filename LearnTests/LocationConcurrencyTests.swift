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

    func testConcurrentBurstWaitersCompleteFromOneBatch() async throws {
        let coordinator = LocationCaptureCoordinator()
        let first = Task { await coordinator.captureLocations(maxSamples: 2, maxDuration: 30, maxSampleAge: 120) }
        let second = Task { await coordinator.captureLocations(maxSamples: 2, maxDuration: 30, maxSampleAge: 120) }

        await waitUntil { coordinator.pendingWaiterCount == 2 }

        let locations = [
            makeLocation(latitude: 51.5, accuracy: 25),
            makeLocation(latitude: 51.6, accuracy: 15)
        ]
        coordinator.receive(locations: locations)

        let firstResult = await first.value
        let secondResult = await second.value

        XCTAssertEqual(firstResult.map(\.coordinate.latitude), locations.map(\.coordinate.latitude))
        XCTAssertEqual(secondResult.map(\.coordinate.latitude), locations.map(\.coordinate.latitude))
        XCTAssertEqual(coordinator.pendingWaiterCount, 0)
    }

    func testBurstFailureResumesEveryWaiter() async throws {
        let coordinator = LocationCaptureCoordinator()
        let first = Task { await coordinator.captureLocations(maxSamples: 2, maxDuration: 30, maxSampleAge: 120) }
        let second = Task { await coordinator.captureLocations(maxSamples: 2, maxDuration: 30, maxSampleAge: 120) }

        await waitUntil { coordinator.pendingWaiterCount == 2 }
        coordinator.fail()

        let firstResult = await first.value
        let secondResult = await second.value

        XCTAssertTrue(firstResult.isEmpty)
        XCTAssertTrue(secondResult.isEmpty)
        XCTAssertEqual(coordinator.pendingWaiterCount, 0)
    }

    func testSingleRequestDuringBatchUsesBatchResult() async throws {
        let coordinator = LocationCaptureCoordinator()
        let batch = Task { await coordinator.captureLocations(maxSamples: 1, maxDuration: 30, maxSampleAge: 120) }
        let single = Task { await coordinator.captureLocation() }

        await waitUntil { coordinator.pendingWaiterCount == 2 }

        let location = makeLocation(latitude: 48.8566, accuracy: 12)
        coordinator.receive(locations: [location])

        let batchResult = await batch.value
        let singleResult = await single.value

        XCTAssertEqual(batchResult.first?.coordinate.latitude, location.coordinate.latitude)
        XCTAssertEqual(singleResult?.coordinate.latitude, location.coordinate.latitude)
        XCTAssertEqual(coordinator.pendingWaiterCount, 0)
    }

    func testBatchTimeoutResumesAndClearsWaiters() async throws {
        let coordinator = LocationCaptureCoordinator()
        let batch = Task { await coordinator.captureLocations(maxSamples: 1, maxDuration: 30, maxSampleAge: 120) }

        await waitUntil { coordinator.pendingWaiterCount == 1 }
        coordinator.expireBatchForTesting()

        let batchResult = await batch.value

        XCTAssertTrue(batchResult.isEmpty)
        XCTAssertEqual(coordinator.pendingWaiterCount, 0)
    }

    private func makeLocation(latitude: Double, accuracy: CLLocationAccuracy) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: -0.12),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 10,
            timestamp: Date()
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for condition", file: file, line: line)
    }
}
