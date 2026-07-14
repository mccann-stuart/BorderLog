import XCTest
@testable import Learn
import Security

final class KeychainHelperTests: XCTestCase {

    // We'll use a specific dummy service identifier to prevent tests from stomping on real data
    private let testService = "com.MCCANN.Border.test"
    private let testAccount = "testAccount"

    override func setUp() {
        super.setUp()
        // Ensure starting state is clean
        KeychainHelper.standard.delete(service: testService, account: testAccount)
    }

    override func tearDown() {
        // Clean up after tests
        KeychainHelper.standard.delete(service: testService, account: testAccount)
        super.tearDown()
    }

    func testSaveAndReadNewItem() {
        let testString = "testSecretData123"
        guard let data = testString.data(using: .utf8) else {
            XCTFail("Failed to convert test string to data")
            return
        }

        // Save
        KeychainHelper.standard.save(data, service: testService, account: testAccount)

        // Read
        let readData = KeychainHelper.standard.read(service: testService, account: testAccount)
        XCTAssertNotNil(readData, "Read data should not be nil")

        if let readData = readData {
            let readString = String(data: readData, encoding: .utf8)
            XCTAssertEqual(readString, testString, "Read data should match saved data")
        }
    }

    func testReadNonExistentItem() {
        // We know it's deleted from setUp()
        let readData = KeychainHelper.standard.read(service: testService, account: testAccount)
        XCTAssertNil(readData, "Reading a non-existent item should return nil")
    }

    func testOverwriteExistingItem() {
        let firstString = "firstData"
        let secondString = "secondData"

        let firstData = firstString.data(using: .utf8)!
        let secondData = secondString.data(using: .utf8)!

        // Save first item
        KeychainHelper.standard.save(firstData, service: testService, account: testAccount)

        // Overwrite by saving to the same service/account
        KeychainHelper.standard.save(secondData, service: testService, account: testAccount)

        // Verify it was updated
        let readData = KeychainHelper.standard.read(service: testService, account: testAccount)
        XCTAssertNotNil(readData)

        if let readData = readData {
            let readString = String(data: readData, encoding: .utf8)
            XCTAssertEqual(readString, secondString, "The item should be overwritten with the second string")
        }
    }

    func testDeleteExistingItem() {
        let testString = "dataToDelete"
        let data = testString.data(using: .utf8)!

        // Save item
        KeychainHelper.standard.save(data, service: testService, account: testAccount)

        // Verify it exists
        XCTAssertNotNil(KeychainHelper.standard.read(service: testService, account: testAccount))

        // Delete item
        KeychainHelper.standard.delete(service: testService, account: testAccount)

        // Verify it was deleted
        XCTAssertNil(KeychainHelper.standard.read(service: testService, account: testAccount), "Data should be nil after deletion")
    }

    func testDeleteNonExistentItem() {
        // Deleting when it doesn't exist shouldn't crash or throw unexpected errors.
        // KeychainHelper handles `errSecItemNotFound` gracefully by not logging an error.
        KeychainHelper.standard.delete(service: testService, account: testAccount)

        // Just verify we can still run code after that
        XCTAssertNil(KeychainHelper.standard.read(service: testService, account: testAccount))
    }
}
