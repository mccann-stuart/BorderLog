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
        // Arrange
        let error = NSError(domain: "TestErrorDomain", code: 1, userInfo: nil)
        mockLocationService.captureAndStoreBurstErrorToThrow = error

        // Ensure no locations exist for today
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

        // Use the internal initializer we added
        let view = MainNavigationView(locationService: mockLocationService)

        // Act - Invoke the explicitly isolated internal method and pass context
        await view.performCaptureTodayLocationIfNeeded(context: modelContext)

        // Assert - The fact that we reach this point means the thrown error was swallowed
        XCTAssertEqual(mockLocationService.captureAndStoreBurstDidCallCount, 1, "The burst capture should have been attempted")
        XCTAssertEqual(mockLocationService.captureAndStoreBurstSource, .app, "The source should be .app")
    }
}
