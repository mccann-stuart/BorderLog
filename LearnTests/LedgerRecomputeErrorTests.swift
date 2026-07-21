//
//  LedgerRecomputeErrorTests.swift
//  LearnTests
//
//  Created by Mccann Stuart on 16/02/2026.
//

#if canImport(XCTest)
import XCTest
import SwiftData
@testable import Learn

@MainActor
final class LedgerRecomputeErrorTests: XCTestCase {

    var container: ModelContainer!
    var service: LedgerRecomputeService!
    var mockFetcher: MockLedgerDataFetcher!
    var recoveryDefaults: UserDefaults!
    var recoverySuiteName: String!
    var recoveryStore: LedgerRecomputeRecoveryStore!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: PresenceDay.self, Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, CalendarSignal.self, configurations: config)
        service = LedgerRecomputeService(modelContainer: container)
        mockFetcher = MockLedgerDataFetcher()
        await service.setMock(mockFetcher)
        recoverySuiteName = "LedgerRecomputeErrorTests.\(UUID().uuidString)"
        recoveryDefaults = try XCTUnwrap(UserDefaults(suiteName: recoverySuiteName))
        recoveryStore = LedgerRecomputeRecoveryStore(defaults: recoveryDefaults)
        await service.setRecoveryStore(recoveryStore)
    }

    override func tearDown() async throws {
        recoveryDefaults?.removePersistentDomain(forName: recoverySuiteName)
        recoveryDefaults = nil
        recoverySuiteName = nil
        recoveryStore = nil
        try await super.tearDown()
    }

    func testFetchStaysFailureAbortsRecompute() async throws {
        struct TestError: Error, Equatable {}
        let expectedError = TestError()
        mockFetcher.fetchStaysError = expectedError

        let expectation = XCTestExpectation(description: "Error handler called")
        await service.setErrorHandler { error in
            if let err = error as? TestError, err == expectedError { expectation.fulfill() }
        }

        do {
            try await service.recompute(dayKeys: ["2024-01-01"])
            XCTFail("Expected fetchStays failure to propagate")
        } catch {
            XCTAssertTrue(error is TestError)
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(mockFetcher.saveCalled)
        XCTAssertEqual(recoveryStore.dirtyDayKeys(), Set(["2024-01-01"]))
    }

    func testFetchOverridesFailureAbortsRecompute() async throws {
        struct TestError: Error, Equatable {}
        let expectedError = TestError()
        mockFetcher.fetchOverridesError = expectedError

        let expectation = XCTestExpectation(description: "Error handler called")
        await service.setErrorHandler { error in
            if let err = error as? TestError, err == expectedError { expectation.fulfill() }
        }

        do {
            try await service.recompute(dayKeys: ["2024-01-01"])
            XCTFail("Expected fetchOverrides failure to propagate")
        } catch {
            XCTAssertTrue(error is TestError)
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(mockFetcher.saveCalled)
        XCTAssertEqual(recoveryStore.dirtyDayKeys(), Set(["2024-01-01"]))
    }

    func testFetchLocationsFailureAbortsRecompute() async throws {
        struct TestError: Error, Equatable {}
        let expectedError = TestError()
        mockFetcher.fetchLocationsError = expectedError

        let expectation = XCTestExpectation(description: "Error handler called")
        await service.setErrorHandler { error in
            if let err = error as? TestError, err == expectedError { expectation.fulfill() }
        }

        do {
            try await service.recompute(dayKeys: ["2024-01-01"])
            XCTFail("Expected fetchLocations failure to propagate")
        } catch {
            XCTAssertTrue(error is TestError)
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(mockFetcher.saveCalled)
        XCTAssertEqual(recoveryStore.dirtyDayKeys(), Set(["2024-01-01"]))
    }

    func testFetchPhotosFailureAbortsRecompute() async throws {
        struct TestError: Error, Equatable {}
        let expectedError = TestError()
        mockFetcher.fetchPhotosError = expectedError

        let expectation = XCTestExpectation(description: "Error handler called")
        await service.setErrorHandler { error in
            if let err = error as? TestError, err == expectedError { expectation.fulfill() }
        }

        do {
            try await service.recompute(dayKeys: ["2024-01-01"])
            XCTFail("Expected fetchPhotos failure to propagate")
        } catch {
            XCTAssertTrue(error is TestError)
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(mockFetcher.saveCalled)
        XCTAssertEqual(recoveryStore.dirtyDayKeys(), Set(["2024-01-01"]))
    }

    func testFetchCalendarSignalsFailureAbortsRecompute() async throws {
        struct TestError: Error, Equatable {}
        let expectedError = TestError()
        mockFetcher.fetchCalendarSignalsError = expectedError

        let expectation = XCTestExpectation(description: "Error handler called")
        await service.setErrorHandler { error in
            if let err = error as? TestError, err == expectedError { expectation.fulfill() }
        }

        do {
            try await service.recompute(dayKeys: ["2024-01-01"])
            XCTFail("Expected fetchCalendarSignals failure to propagate")
        } catch {
            XCTAssertTrue(error is TestError)
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(mockFetcher.saveCalled)
        XCTAssertEqual(recoveryStore.dirtyDayKeys(), Set(["2024-01-01"]))
    }

    func testSaveFailureIsReported() async throws {
        // Given
        struct TestError: Error, Equatable {}
        let expectedError = TestError()
        mockFetcher.saveError = expectedError

        let expectation = XCTestExpectation(description: "Error handler called")

        await service.setErrorHandler { error in
            if let err = error as? TestError, err == expectedError {
                expectation.fulfill()
            }
        }

        // When
        do {
            try await service.recompute(dayKeys: ["2024-01-01"])
            XCTFail("Expected save failure to propagate")
        } catch {
            XCTAssertTrue(error is TestError)
        }

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(mockFetcher.saveCalled, "Save should be attempted")
        XCTAssertEqual(recoveryStore.dirtyDayKeys(), Set(["2024-01-01"]))
    }

    func testSuccessfulRecomputeClearsCompletedDirtyKey() async throws {
        let dayKey = DayKey.make(from: Date(), timeZone: .current)

        try await service.recompute(dayKeys: [dayKey])

        XCTAssertTrue(mockFetcher.saveCalled)
        XCTAssertFalse(recoveryStore.dirtyDayKeys().contains(dayKey))
    }
}

extension LedgerRecomputeService {
    func setMock(_ mock: LedgerDataFetching) {
        self._dataFetcher = mock
    }

    func setErrorHandler(_ handler: @escaping (Error) -> Void) {
        self.onRecomputeError = handler
    }
}
#endif
