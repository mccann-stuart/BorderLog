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
        container = try ModelContainer(for: PresenceDay.self, Stay.self, DayOverride.self, LocationSample.self, PhotoSignal.self, configurations: config)
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
        await service.recompute(dayKeys: ["2024-01-01"])

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
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
        await service.recompute(dayKeys: ["2024-01-01"])

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(mockFetcher.saveCalled, "Save should be attempted")
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
