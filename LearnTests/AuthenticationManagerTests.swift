import XCTest
@testable import Learn
import Security

// Mock KeychainHelper
class MockKeychainHelper: KeychainHelperProtocol {
    var storage: [String: Data] = [:]
    var saveCalls: [(data: Data, service: String, account: String)] = []

    func save(_ data: Data, service: String, account: String) {
        saveCalls.append((data: data, service: service, account: account))
        let key = "\(service)-\(account)"
        storage[key] = data
    }

    func read(service: String, account: String) -> Data? {
        let key = "\(service)-\(account)"
        return storage[key]
    }

    func delete(service: String, account: String) {
        let key = "\(service)-\(account)"
        storage.removeValue(forKey: key)
    }
}

@MainActor
final class AuthenticationManagerTests: XCTestCase {
    func testKeychainUsesDeviceBoundAccessibility() {
        XCTAssertEqual(
            KeychainHelper.defaultAccessibility as String,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as String
        )
    }

    func testSignInSavesToKeychain() {
        let mockKeychain = MockKeychainHelper()
        let manager = AuthenticationManager(keychain: mockKeychain)
        let userId = "testUser123"

        manager.signIn(userId: userId)

        XCTAssertEqual(manager.appleUserId, userId)

        // Verify the save function is called with the correct parameters
        XCTAssertEqual(mockKeychain.saveCalls.count, 1)
        if let firstCall = mockKeychain.saveCalls.first {
            XCTAssertEqual(firstCall.service, "com.MCCANN.Border")
            XCTAssertEqual(firstCall.account, "appleUserId")
            XCTAssertEqual(String(data: firstCall.data, encoding: .utf8), userId)
        } else {
            XCTFail("Expected mockKeychain.save to be called")
        }

        let storedData = mockKeychain.read(service: "com.MCCANN.Border", account: "appleUserId")
        XCTAssertNotNil(storedData)
        XCTAssertEqual(String(data: storedData!, encoding: .utf8), userId)
    }

    func testSignOutDeletesFromKeychain() {
        let mockKeychain = MockKeychainHelper()
        let userId = "testUser123"
        // Pre-populate mock keychain
        if let data = userId.data(using: .utf8) {
             mockKeychain.save(data, service: "com.MCCANN.Border", account: "appleUserId")
        }

        let manager = AuthenticationManager(keychain: mockKeychain)
        // Verify initial state from init
        XCTAssertEqual(manager.appleUserId, userId)

        manager.signOut()

        XCTAssertEqual(manager.appleUserId, "")

        let storedData = mockKeychain.read(service: "com.MCCANN.Border", account: "appleUserId")
        XCTAssertNil(storedData)
    }

    func testInitReadsFromKeychain() {
        let mockKeychain = MockKeychainHelper()
        let userId = "existingUser456"
        if let data = userId.data(using: .utf8) {
            mockKeychain.save(data, service: "com.MCCANN.Border", account: "appleUserId")
        }

        let manager = AuthenticationManager(keychain: mockKeychain)

        XCTAssertEqual(manager.appleUserId, userId)
    }

    func testInitWithEmptyKeychain() {
        let mockKeychain = MockKeychainHelper()
        let manager = AuthenticationManager(keychain: mockKeychain)

        XCTAssertEqual(manager.appleUserId, "")
    }
}
