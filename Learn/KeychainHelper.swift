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
    private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "Keychain")

    private init() {}

    func save(_ data: Data, service: String, account: String) {
        // Create query for deletion (no data)
        let deleteQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary

        // Delete any existing item
        SecItemDelete(deleteQuery)

        // Create query for adding (with data)
        let addQuery = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked
        ] as CFDictionary

        // Add new item
        let status = SecItemAdd(addQuery, nil)

        if status != errSecSuccess {
            Self.logger.error("Error saving to Keychain: \(status, privacy: .public)")
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
            return nil
        }
    }

    func delete(service: String, account: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary

        SecItemDelete(query)
    }
}
