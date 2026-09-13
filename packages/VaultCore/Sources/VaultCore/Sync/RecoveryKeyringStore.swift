import Foundation

public enum RecoveryKeyringStore {
    public static let keyringPreferenceKey = "cloud-backup-recovery-keyring"

    public static func load(from prefs: PreferenceStoring, now: Date = Date()) -> RecoveryKeyring {
        if let data = prefs.data(forKey: keyringPreferenceKey),
           let keyring = decode(data) {
            return keyring
        }
        guard let legacy = legacyKey(from: prefs) else {
            return RecoveryKeyring()
        }
        var keyring = RecoveryKeyring()
        try? keyring.makeActive(legacy, at: now, imported: false)
        save(keyring, to: prefs)
        return keyring
    }

    public static func save(_ keyring: RecoveryKeyring, to prefs: PreferenceStoring) {
        if let data = encode(keyring) {
            prefs.set(data, forKey: keyringPreferenceKey)
        }
        if let active = keyring.activeCanonicalKey {
            prefs.set(Data(active.utf8), forKey: CloudRecoveryKey.preferenceKey)
        } else {
            prefs.set(nil, forKey: CloudRecoveryKey.preferenceKey)
        }
    }

    private static func legacyKey(from prefs: PreferenceStoring) -> String? {
        guard let data = prefs.data(forKey: CloudRecoveryKey.preferenceKey),
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty,
              let canonical = try? CloudRecoveryKey.canonicalize(value) else {
            return nil
        }
        return canonical
    }

    private static func encode(_ keyring: RecoveryKeyring) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(keyring)
    }

    private static func decode(_ data: Data) -> RecoveryKeyring? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(RecoveryKeyring.self, from: data)
    }
}
