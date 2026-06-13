import Foundation
import VaultCore
import CryptoKit

// MARK: - Encryption

extension CloudBackupService {
    func encryptBackup(_ data: String) -> String? {
        // In production, use proper encryption with a key derived from user's password
        // For now, this is a simplified version
        guard let dataBytes = data.data(using: .utf8) else { return nil }

        // Generate a random key or use a key from secure storage
        let key = SymmetricKey(size: .bits256)

        do {
            let sealedBox = try AES.GCM.seal(dataBytes, using: key)
            return sealedBox.combined?.base64EncodedString()
        } catch {
            print("Encryption error: \(error)")
            return nil
        }
    }

    func decryptBackup(_ encryptedData: String) -> String? {
        // In production, retrieve the key from secure storage
        // This is a simplified version
        guard let data = Data(base64Encoded: encryptedData) else { return nil }

        // Key should be the same used for encryption
        let key = SymmetricKey(size: .bits256)

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            print("Decryption error: \(error)")
            return nil
        }
    }
}

// MARK: - Serialization

extension CloudBackupService {
    func serializeSecrets(_ secrets: [Secret]) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let backupData = secrets.map { secret -> [String: Any] in
            return [
                "name": secret.name,
                "value": secret.value,
                "notes": secret.notes ?? "",
                "expiresAt": secret.expiresAt?.iso8601String ?? "",
                "rotateEveryDays": secret.rotateEveryDays ?? 0,
                "mcpAllowed": secret.mcpAllowed
            ]
        }

        let jsonData = try JSONSerialization.data(withJSONObject: backupData, options: .sortedKeys)
        return String(data: jsonData, encoding: .utf8) ?? ""
    }

    func deserializeSecrets(_ data: String) throws -> [Secret] {
        guard let jsonData = data.data(using: .utf8) else { return [] }

        let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] ?? []

        return jsonArray.compactMap { dict -> Secret? in
            guard let name = dict["name"] as? String,
                  let value = dict["value"] as? String else { return nil }

            let notes = dict["notes"] as? String
            let expiresAtString = dict["expiresAt"] as? String
            let expiresAt = expiresAtString?.isEmpty == false ? ISO8601DateFormatter().date(from: expiresAtString!) : nil
            let rotateEveryDays = dict["rotateEveryDays"] as? Int
            let mcpAllowed = dict["mcpAllowed"] as? Bool ?? false

            return Secret(
                name: name,
                value: value,
                notes: notes,
                expiresAt: expiresAt,
                rotateEveryDays: rotateEveryDays,
                mcpAllowed: mcpAllowed
            )
        }
    }

    func calculateChecksum(_ data: String) -> String {
        guard let dataBytes = data.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: dataBytes)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
