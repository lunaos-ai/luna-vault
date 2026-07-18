import Foundation
import Security

/// Open Keychain ACL for **legacy** `KeychainStore` secret items only (migration ergonomics).
/// Do not use for prefs, provider tokens, or the vault master key.
enum KeychainAccess {
    static func openAccess(label: String = "Vibe Vault") -> SecAccess? {
        var access: SecAccess?
        let status = SecAccessCreate(label as CFString, nil, &access)
        guard status == errSecSuccess else { return nil }
        return access
    }

    static func applyOpenAccess(_ query: inout [String: Any], label: String = "Vibe Vault") {
        if let access = openAccess(label: label) {
            query[kSecAttrAccess as String] = access
        }
    }
}
