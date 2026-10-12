import Foundation
import Security

enum KeychainHelper {
    private static let service = "ai.abacus.hockeyinfo"

    static func save(_ value: String, forKey key: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(base as CFDictionary)
        guard let data = value.data(using: .utf8) else { return }
        var attrs = base
        attrs[kSecValueData as String] = data
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func load(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func deleteAll() {
        for key in ["email", "password", "cookies", "playerName", "teamName", "playerId", "seasonId", "clubId"] {
            delete(key)
        }
    }

    // Legacy compatibility for generated APIClient
    static var authToken: String? {
        get { load("auth_token") }
        set { if let v = newValue { save(v, forKey: "auth_token") } else { delete("auth_token") } }
    }

    // Convenience
    static var email: String? {
        get { load("email") }
        set { if let v = newValue { save(v, forKey: "email") } else { delete("email") } }
    }
    static var password: String? {
        get { load("password") }
        set { if let v = newValue { save(v, forKey: "password") } else { delete("password") } }
    }
    static var playerName: String? {
        get { load("playerName") }
        set { if let v = newValue { save(v, forKey: "playerName") } else { delete("playerName") } }
    }
    static var teamName: String? {
        get { load("teamName") }
        set { if let v = newValue { save(v, forKey: "teamName") } else { delete("teamName") } }
    }
}
