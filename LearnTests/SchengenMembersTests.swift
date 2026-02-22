#if canImport(XCTest)
import XCTest
@testable import Learn

final class SchengenMembersTests: XCTestCase {

    // MARK: - Happy Paths (Valid Members)

    func testIsMember_withUppercasedValidCode_returnsTrue() {
        XCTAssertTrue(SchengenMembers.isMember("ES"))
        XCTAssertTrue(SchengenMembers.isMember("FR"))
        XCTAssertTrue(SchengenMembers.isMember("DE"))
        XCTAssertTrue(SchengenMembers.isMember("IT"))
    }

    func testIsMember_withLowercasedValidCode_returnsTrue() {
        XCTAssertTrue(SchengenMembers.isMember("es"))
        XCTAssertTrue(SchengenMembers.isMember("fr"))
        XCTAssertTrue(SchengenMembers.isMember("de"))
        XCTAssertTrue(SchengenMembers.isMember("it"))
    }

    func testIsMember_withMixedCaseValidCode_returnsTrue() {
        XCTAssertTrue(SchengenMembers.isMember("Es"))
        XCTAssertTrue(SchengenMembers.isMember("fR"))
        XCTAssertTrue(SchengenMembers.isMember("dE"))
        XCTAssertTrue(SchengenMembers.isMember("It"))
    }

    func testIsMember_withSurroundingWhitespace_returnsTrue() {
        XCTAssertTrue(SchengenMembers.isMember("  ES  "))
        XCTAssertTrue(SchengenMembers.isMember("\tFR\n"))
        XCTAssertTrue(SchengenMembers.isMember(" DE "))
    }

    // MARK: - Edge Cases & Error Conditions

    func testIsMember_withInvalidCode_returnsFalse() {
        XCTAssertFalse(SchengenMembers.isMember("GB")) // UK is not Schengen
        XCTAssertFalse(SchengenMembers.isMember("US")) // US is not Schengen
        XCTAssertFalse(SchengenMembers.isMember("XX")) // Non-existent code
        XCTAssertFalse(SchengenMembers.isMember("12")) // Numeric
    }

    func testIsMember_withEmptyString_returnsFalse() {
        XCTAssertFalse(SchengenMembers.isMember(""))
    }

    func testIsMember_withWhitespaceOnlyString_returnsFalse() {
        XCTAssertFalse(SchengenMembers.isMember("   "))
        XCTAssertFalse(SchengenMembers.isMember("\t"))
        XCTAssertFalse(SchengenMembers.isMember("\n"))
    }

    func testIsMember_withNil_returnsFalse() {
        XCTAssertFalse(SchengenMembers.isMember(nil))
    }
}
#endif
