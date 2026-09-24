import Foundation
import Security

enum Keychain {
    private static let service = "com.benstrohbeen.DriveAudioPlayer"
    /// Tokens are refreshed during locked-screen background playback, so the
    /// item must be writable after first unlock. Device-only: it must not
    /// migrate to another device via backup.
    private static var accessibility: CFString { kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly }

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    /// Updates in place and only adds when absent. Never delete-then-add: if the
    /// add were refused (e.g. device locked) the previous value would be lost.
    static func save(_ value: Data, account: String) throws {
        let attributes: [String: Any] = [kSecValueData as String: value, kSecAttrAccessible as String: accessibility]
        var status = SecItemUpdate(query(account) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query(account).merging(attributes) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }
    static func read(account: String) -> Data? {
        var q = query(account); q[kSecReturnData as String] = true
        var result: CFTypeRef?; guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
    static func delete(account: String) { SecItemDelete(query(account) as CFDictionary) }

    struct KeychainError: Error { let status: OSStatus }
}
