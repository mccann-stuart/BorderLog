import XCTest
import CoreLocation
@testable import Learn

final class LocationSampleServiceAuthorizationTests: XCTestCase {
    func testAppCaptureAllowedWhenAuthorized() {
        let allowedWhenInUse = LocationSampleService.isCaptureAuthorized(
            source: .app,
            status: .authorizedWhenInUse,
            isAuthorizedForWidgetUpdates: false
        )
        let allowedAlways = LocationSampleService.isCaptureAuthorized(
            source: .app,
            status: .authorizedAlways,
            isAuthorizedForWidgetUpdates: false
        )

        XCTAssertTrue(allowedWhenInUse)
        XCTAssertTrue(allowedAlways)
    }

    func testAppCaptureBlockedWhenNotDeterminedOrDenied() {
        let blockedNotDetermined = LocationSampleService.isCaptureAuthorized(
            source: .app,
            status: .notDetermined,
            isAuthorizedForWidgetUpdates: true
        )
        let blockedDenied = LocationSampleService.isCaptureAuthorized(
            source: .app,
            status: .denied,
            isAuthorizedForWidgetUpdates: true
        )

        XCTAssertFalse(blockedNotDetermined)
        XCTAssertFalse(blockedDenied)
    }

    func testWidgetCaptureAllowedWhenLocationAuthorizedAndWidgetAuthorized() {
        let allowed = LocationSampleService.isCaptureAuthorized(
            source: .widget,
            status: .authorizedWhenInUse,
            isAuthorizedForWidgetUpdates: true
        )

        XCTAssertTrue(allowed)
    }

    func testWidgetCaptureBlockedWhenWidgetUpdatesUnauthorized() {
        let blocked = LocationSampleService.isCaptureAuthorized(
            source: .widget,
            status: .authorizedAlways,
            isAuthorizedForWidgetUpdates: false
        )

        XCTAssertFalse(blocked)
    }

    func testWidgetCaptureBlockedWhenLocationDenied() {
        let blocked = LocationSampleService.isCaptureAuthorized(
            source: .widget,
            status: .denied,
            isAuthorizedForWidgetUpdates: true
        )

        XCTAssertFalse(blocked)
    }
}
