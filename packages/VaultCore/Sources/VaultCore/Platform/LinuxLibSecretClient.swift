#if os(Linux)
import CLibSecret
import Foundation

struct LibSecretClient: LinuxSecretServiceClient {
    var isAvailable: Bool { vv_secret_is_available() != 0 }

    func lookup(account: String) throws -> Data? {
        var hex: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        defer {
            vv_secret_string_free(hex)
            vv_secret_string_free(error)
        }
        let status = account.withCString { accountPtr in
            vv_secret_lookup(accountPtr, &hex, &error)
        }
        switch status {
        case 0:
            guard let hex else { throw SecretError.vaultIO("empty libsecret lookup") }
            let decoded = try LinuxMasterKeyHex.decode(String(cString: hex))
            guard decoded.count == 32 else {
                throw SecretError.vaultIO("corrupt libsecret master key")
            }
            return decoded
        case 1, 2:
            return nil
        default:
            throw SecretError.vaultIO(error.map { String(cString: $0) } ?? "libsecret lookup failed")
        }
    }

    func store(account: String, key: Data) throws {
        guard key.count == 32 else { throw SecretError.vaultIO("master key must be 32 bytes") }
        let hex = LinuxMasterKeyHex.encode(key)
        var error: UnsafeMutablePointer<CChar>?
        defer { vv_secret_string_free(error) }
        let status = account.withCString { accountPtr in
            hex.withCString { hexPtr in
                "Vibe Vault master key".withCString { labelPtr in
                    vv_secret_store(accountPtr, labelPtr, hexPtr, &error)
                }
            }
        }
        guard status == 0 else {
            throw SecretError.vaultIO(error.map { String(cString: $0) } ?? "libsecret store failed")
        }
    }

    func delete(account: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        defer { vv_secret_string_free(error) }
        let status = account.withCString { accountPtr in
            vv_secret_clear(accountPtr, &error)
        }
        guard status == 0 || status == 1 || status == 2 else {
            throw SecretError.vaultIO(error.map { String(cString: $0) } ?? "libsecret clear failed")
        }
    }
}
#endif
