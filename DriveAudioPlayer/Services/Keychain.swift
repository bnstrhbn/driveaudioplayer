import Foundation
import Security

enum Keychain {
    static func save(_ value: Data, account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.benstrohbeen.DriveAudioPlayer", kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        var add = query; add[kSecValueData as String] = value
        guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { throw CocoaError(.fileWriteUnknown) }
    }
    static func read(account: String) -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.benstrohbeen.DriveAudioPlayer", kSecAttrAccount as String: account, kSecReturnData as String: true]
        var result: CFTypeRef?; guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
    static func delete(account: String) { SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.benstrohbeen.DriveAudioPlayer", kSecAttrAccount as String: account] as CFDictionary) }
}
