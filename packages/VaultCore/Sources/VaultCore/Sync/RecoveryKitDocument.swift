import Foundation

public enum RecoveryKitDocument {
    public static func contents(canonicalKey: String, createdAt: Date = Date()) throws -> String {
        let fingerprint = try CloudRecoveryKey.fingerprint(forKey: canonicalKey)
        let created = ISO8601DateFormatter().string(from: createdAt)
        return """
        VIBE VAULT RECOVERY KIT

        Fingerprint: \(fingerprint)
        Created: \(created)

        Recovery key:
        \(canonicalKey)

        Use this key in Vibe Vault > Cloud Sync > Restore with recovery key.
        Store this file separately from your encrypted .vvsync backups.
        Anyone with this key and a protected backup can read that backup.
        """
    }
}
