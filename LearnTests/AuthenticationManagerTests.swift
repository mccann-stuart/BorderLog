import XCTest
@testable import Learn

// Mock KeychainHelper
class MockKeychainHelper: KeychainHelperProtocol {
    var storage: [String: Data] = [:]

    func save(_ data: Data, service: String, account: String) {
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

    func testSignInSavesToKeychain() {
        let mockKeychain = MockKeychainHelper()
        let manager = AuthenticationManager(keychain: mockKeychain)
        let userId = "testUser123"

        manager.signIn(userId: userId)

        XCTAssertEqual(manager.appleUserId, userId)

        let storedData = mockKeychain.read(service: "com.MCCANN.Learn", account: "appleUserId")
        XCTAssertNotNil(storedData)
        XCTAssertEqual(String(data: storedData!, encoding: .utf8), userId)
    }

    func testSignOutDeletesFromKeychain() {
        let mockKeychain = MockKeychainHelper()
        let userId = "testUser123"
        // Pre-populate mock keychain
        if let data = userId.data(using: .utf8) {
             mockKeychain.save(data, service: "com.MCCANN.Learn", account: "appleUserId")
        }

        let manager = AuthenticationManager(keychain: mockKeychain)
        // Verify initial state from init
        XCTAssertEqual(manager.appleUserId, userId)

        manager.signOut()

        XCTAssertEqual(manager.appleUserId, "")

        let storedData = mockKeychain.read(service: "com.MCCANN.Learn", account: "appleUserId")
        XCTAssertNil(storedData)
    }

    func testInitReadsFromKeychain() {
        let mockKeychain = MockKeychainHelper()
        let userId = "existingUser456"
        if let data = userId.data(using: .utf8) {
            mockKeychain.save(data, service: "com.MCCANN.Learn", account: "appleUserId")
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
