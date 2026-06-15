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
    static let defaultAccessibility = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
    private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "Security")

    private static let accessGroup: String? = {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "team_id_resolver",
            kSecAttrService: "com.MCCANN.Border.resolver",
            kSecReturnAttributes: true
        ]

        var result: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            let addQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: "team_id_resolver",
                kSecAttrService: "com.MCCANN.Border.resolver",
                kSecValueData: Data(),
                kSecReturnAttributes: true
            ]
            status = SecItemAdd(addQuery as CFDictionary, &result)
        }

        guard status == errSecSuccess,
              let attributes = result as? [String: Any],
              let accessGroup = attributes[kSecAttrAccessGroup as String] as? String else {
            logger.error("Failed to resolve Keychain access group. Status: \(status, privacy: .private)")
            return nil
        }

        let prefix = accessGroup.components(separatedBy: ".").first ?? ""
        return "\(prefix).group.com.MCCANN.Border"
    }()

    private init() {}

    func save(_ data: Data, service: String, account: String) {
        // Create query for deletion (no data)
        var deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service as CFString,
            kSecAttrAccount: account as CFString
        ]

        if let accessGroup = Self.accessGroup {
            deleteQuery[kSecAttrAccessGroup] = accessGroup as CFString
        }

        // Delete any existing item
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            Self.logger.error("Error deleting existing item during save to Keychain: \(deleteStatus, privacy: .private)")
        }

        // Create query for adding (with data)
        var addQuery: [CFString: Any] = [
            kSecValueData: data as CFData,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service as CFString,
            kSecAttrAccount: account as CFString,
            kSecAttrAccessible: Self.defaultAccessibility
        ]

        if let accessGroup = Self.accessGroup {
            addQuery[kSecAttrAccessGroup] = accessGroup as CFString
        }

        // Add new item
        let status = SecItemAdd(addQuery as CFDictionary, nil)

        if status != errSecSuccess {
            Self.logger.error("Error saving to Keychain: \(status, privacy: .private)")
        }
    }

    func read(service: String, account: String) -> Data? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service as CFString,
            kSecAttrAccount: account as CFString,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        if let accessGroup = Self.accessGroup {
            query[kSecAttrAccessGroup] = accessGroup as CFString
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

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
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service as CFString,
            kSecAttrAccount: account as CFString
        ]

        if let accessGroup = Self.accessGroup {
            query[kSecAttrAccessGroup] = accessGroup as CFString
        }

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            Self.logger.error("Error deleting from Keychain: \(status, privacy: .private)")
        }
    }
}
