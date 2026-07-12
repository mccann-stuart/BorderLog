import XCTest
import LocalAuthentication
@testable import Learn

final class SecurityLockViewTests: XCTestCase {
    func testAppCancellationIsNeutral() {
        XCTAssertTrue(isNeutralAuthenticationCancellation(error(for: .appCancel)))
    }

    func testSystemCancellationIsNeutral() {
        XCTAssertTrue(isNeutralAuthenticationCancellation(error(for: .systemCancel)))
    }

    func testUserCancellationIsNotNeutral() {
        XCTAssertFalse(isNeutralAuthenticationCancellation(error(for: .userCancel)))
    }

    func testAuthenticationFailureIsNotNeutral() {
        XCTAssertFalse(isNeutralAuthenticationCancellation(error(for: .authenticationFailed)))
    }

    func testMissingErrorIsNotNeutral() {
        XCTAssertFalse(isNeutralAuthenticationCancellation(nil))
    }

    func testNonLocalAuthenticationErrorIsNotNeutral() {
        let error = NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileNoSuchFile.rawValue)

        XCTAssertFalse(isNeutralAuthenticationCancellation(error))
    }

    private func error(for code: LAError.Code) -> NSError {
        NSError(domain: LAError.errorDomain, code: code.rawValue)
    }
}
