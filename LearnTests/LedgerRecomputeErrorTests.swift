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

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: PresenceDay.self, Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, CalendarSignal.self, configurations: config)
        service = LedgerRecomputeService(modelContainer: container)
        mockFetcher = MockLedgerDataFetcher()
        await service.setMock(mockFetcher)
    }

    func testFetchFailureAbortsRecompute() async throws {
        // Given
        struct TestError: Error, Equatable {}
        let expectedError = TestError()
        mockFetcher.fetchStaysError = expectedError

        let expectation = XCTestExpectation(description: "Error handler called")

        await service.setErrorHandler { error in
            if let err = error as? TestError, err == expectedError {
                expectation.fulfill()
            }
        }

        // When
        let succeeded = await service.recompute(dayKeys: [todayKey])

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(succeeded)
        XCTAssertFalse(mockFetcher.saveCalled, "Save should not be called if fetch fails")
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
        let succeeded = await service.recompute(dayKeys: [todayKey])

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(succeeded)
        XCTAssertTrue(mockFetcher.saveCalled, "Save should be attempted")
    }

    func testSuccessfulRecomputeReturnsTrue() async {
        let succeeded = await service.recompute(dayKeys: [todayKey])

        XCTAssertTrue(succeeded)
        XCTAssertTrue(mockFetcher.saveCalled)
    }

    func testExistingPresenceDayFetchFailureReturnsFalse() async {
        struct TestError: Error {}
        mockFetcher.fetchPresenceDaysError = TestError()

        let succeeded = await service.recompute(dayKeys: [todayKey])

        XCTAssertFalse(succeeded)
        XCTAssertFalse(mockFetcher.saveCalled)
    }

    func testRecomputeAllPresenceDayBoundsFailureReturnsFalse() async {
        struct TestError: Error, Equatable {}
        let expectedError = TestError()
        mockFetcher.fetchPresenceDayBoundsError = expectedError

        let expectation = XCTestExpectation(description: "Error handler called")
        await service.setErrorHandler { error in
            if let error = error as? TestError, error == expectedError {
                expectation.fulfill()
            }
        }

        let succeeded = await service.recomputeAll()

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(succeeded)
        XCTAssertFalse(mockFetcher.saveCalled)
    }

    func testRecomputeAllFutureCacheDeletionFailureReturnsFalse() async {
        struct TestError: Error, Equatable {}
        let expectedError = TestError()
        mockFetcher.deletePresenceDaysError = expectedError

        let expectation = XCTestExpectation(description: "Error handler called")
        await service.setErrorHandler { error in
            if let error = error as? TestError, error == expectedError {
                expectation.fulfill()
            }
        }

        let succeeded = await service.recomputeAll()

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(succeeded)
        XCTAssertTrue(mockFetcher.saveCalled, "Historical recompute should save before future cache cleanup")
    }

    private var todayKey: String {
        let calendar = Calendar.current
        return DayKey.make(from: calendar.startOfDay(for: Date()), timeZone: calendar.timeZone)
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
