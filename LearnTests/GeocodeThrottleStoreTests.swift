//
//  GeocodeThrottleStoreTests.swift
//  LearnTests
//

import XCTest
@testable import Learn

final class GeocodeThrottleStoreTests: XCTestCase {

    private var userDefaults: UserDefaults!
    private let suiteName = "test.geocode.throttle.store.\(UUID().uuidString)"
    private let stateKey = "borderlog.geocode.throttle.state"

    override func setUp() {
        super.setUp()
        // Use a unique suite name for tests to avoid state bleed
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        // Clean up the UserDefaults after tests
        userDefaults?.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        super.tearDown()
    }

    func testIsAvailable_WithNilDefaults_ReturnsFalse() {
        let store = GeocodeThrottleStore(defaults: nil)
        XCTAssertFalse(store.isAvailable)
    }

    func testIsAvailable_WithValidDefaults_ReturnsTrue() {
        let store = GeocodeThrottleStore(defaults: userDefaults)
        XCTAssertTrue(store.isAvailable)
    }

    func testLoadState_WithNilDefaults_ReturnsEmptyState() {
        let store = GeocodeThrottleStore(defaults: nil)
        let state = store.loadState()
        XCTAssertTrue(state.timestamps.isEmpty)
        XCTAssertNil(state.blockedUntil)
    }

    func testLoadState_WithNoData_ReturnsEmptyState() {
        let store = GeocodeThrottleStore(defaults: userDefaults)
        let state = store.loadState()
        XCTAssertTrue(state.timestamps.isEmpty)
        XCTAssertNil(state.blockedUntil)
    }

    func testSaveAndLoadState_WithValidData_ReturnsSavedState() {
        let store = GeocodeThrottleStore(defaults: userDefaults)

        let expectedTimestamps: [TimeInterval] = [1000, 2000]
        let expectedBlockedUntil: TimeInterval = 3000
        let stateToSave = GeocodeThrottleState(timestamps: expectedTimestamps, blockedUntil: expectedBlockedUntil)

        store.saveState(stateToSave)

        let loadedState = store.loadState()
        XCTAssertEqual(loadedState.timestamps, expectedTimestamps)
        XCTAssertEqual(loadedState.blockedUntil, expectedBlockedUntil)
    }

    func testLoadState_WithInvalidData_ReturnsEmptyState() {
        // Manually save invalid data
        userDefaults.set("invalid json string".data(using: .utf8)!, forKey: stateKey)

        let store = GeocodeThrottleStore(defaults: userDefaults)
        let state = store.loadState()

        XCTAssertTrue(state.timestamps.isEmpty)
        XCTAssertNil(state.blockedUntil)
    }

    func testUpdate_WithNilDefaults_ReturnsEmptyState() {
        let store = GeocodeThrottleStore(defaults: nil)
        let state = store.update { state in
            state.timestamps = [100]
        }

        XCTAssertTrue(state.timestamps.isEmpty)
    }

    func testUpdate_WithValidDefaults_ModifiesAndSavesState() {
        let store = GeocodeThrottleStore(defaults: userDefaults)

        // Initial setup
        store.saveState(GeocodeThrottleState(timestamps: [100], blockedUntil: nil))

        // Update
        let returnedState = store.update { state in
            state.timestamps.append(200)
            state.blockedUntil = 500
        }

        // Verify returned state
        XCTAssertEqual(returnedState.timestamps, [100, 200])
        XCTAssertEqual(returnedState.blockedUntil, 500)

        // Verify saved state
        let loadedState = store.loadState()
        XCTAssertEqual(loadedState.timestamps, [100, 200])
        XCTAssertEqual(loadedState.blockedUntil, 500)
    }
}
