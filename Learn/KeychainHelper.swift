import Foundation
import Security
import os

protocol KeychainHelperProtocol {
    func save(_ data: Data, service: String, account: String)
    func read(service: String, account: String) -> Data?
    func delete(service: String, account: String)
}

final class KeychainHelper: KeychainHelperProtocol {
    static let standard = KeychainHelper()
    static let defaultAccessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "Security")

    private init() {}

    func save(_ data: Data, service: String, account: String) {
        // Create query for deletion (no data)
        let deleteQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary

        // Delete any existing item
        let deleteStatus = SecItemDelete(deleteQuery)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            Self.logger.error("Error deleting existing item during save to Keychain: \(deleteStatus, privacy: .private)")
        }

        // Create query for adding (with data)
        let addQuery = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: Self.defaultAccessibility
        ] as CFDictionary

        // Add new item
        let status = SecItemAdd(addQuery, nil)

        if status != errSecSuccess {
            Self.logger.error("Error saving to Keychain: \(status, privacy: .private)")
        }
    }

    func read(service: String, account: String) -> Data? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary

        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)

        if status == errSecSuccess {
            return result as? Data
        } else {
            if status != errSecItemNotFound {
                Self.logger.error("Error reading from Keychain: \(status, privacy: .private)")
            }
            return nil
        }
    }

    func delete(service: String, account: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary

        let status = SecItemDelete(query)
        if status != errSecSuccess && status != errSecItemNotFound {
            Self.logger.error("Error deleting from Keychain: \(status, privacy: .private)")
        }
    }
}
