import XCTest
import SwiftData
import SwiftUI
@testable import Learn

@MainActor
final class MainNavigationViewTests: XCTestCase {
    var container: ModelContainer!
    var modelContext: ModelContext!
    var mockLocationService: MockLocationSampleService!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: LocationSample.self,
            PhotoIngestState.self,
            PhotoSignal.self,
            Stay.self,
            DayOverride.self,
            PresenceDay.self,
            CalendarSignal.self,
            configurations: config
        )
        modelContext = container.mainContext
        mockLocationService = MockLocationSampleService()

        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")

        container = nil
        modelContext = nil
        mockLocationService = nil
    }

    func testPerformCaptureTodayLocationResilientToCaptureError() async throws {
        let error = NSError(domain: "TestErrorDomain", code: 1, userInfo: nil)
        mockLocationService.captureAndStoreBurstErrorToThrow = error

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = #Predicate<LocationSample> { sample in
            sample.timestamp >= startOfDay && sample.timestamp < endOfDay
        }
        var fetch = FetchDescriptor<LocationSample>(predicate: predicate)
        fetch.fetchLimit = 1
        let existing = try modelContext.fetch(fetch)
        XCTAssertTrue(existing.isEmpty, "Should be no locations before test")

        let view = MainNavigationView(locationService: mockLocationService)
        await view.performCaptureTodayLocationIfNeeded(context: modelContext)

        XCTAssertEqual(mockLocationService.captureAndStoreBurstDidCallCount, 1)
        XCTAssertEqual(mockLocationService.captureAndStoreBurstSource, .app)
    }

    func testPerformCaptureTodayLocationAttemptsCaptureAfterFetchError() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let containerWithoutLocationSamples = try ModelContainer(
            for: Stay.self,
            configurations: config
        )
        let failingContext = containerWithoutLocationSamples.mainContext
        let view = MainNavigationView(locationService: mockLocationService)

        await view.performCaptureTodayLocationIfNeeded(context: failingContext)

        XCTAssertEqual(mockLocationService.captureAndStoreBurstDidCallCount, 1)
        XCTAssertEqual(mockLocationService.captureAndStoreBurstSource, .app)
        XCTAssertTrue(mockLocationService.captureAndStoreBurstModelContext === failingContext)
    }
}
