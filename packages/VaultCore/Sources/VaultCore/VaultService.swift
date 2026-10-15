import Foundation

/// Composes encrypted vault (or Keychain) + AuditDB + AgentDetector + BiometricGate.
/// Every secret read goes through this façade so audit cannot be bypassed.
public final class VaultService: @unchecked Sendable {
    public let store: KeychainStoring
    public let audit: AuditLogging
    public let detector: AgentDetecting
    public let biometric: BiometricGating
    public let sessionId: String
    private let cacheQueue = DispatchQueue(label: "dev.vibevault.readcache")
    private var readCache: [String: Secret] = [:]

    public init(
        store: KeychainStoring,
        audit: AuditLogging,
        detector: AgentDetecting,
        biometric: BiometricGating,
        sessionId: String = SessionID.current()
    ) {
        self.store = store
        self.audit = audit
        self.detector = detector
        self.biometric = biometric
        self.sessionId = sessionId
    }

    public static func live() throws -> VaultService {
        VaultService(
            store: MigratingVaultStore(),
            audit: try AuditDB(),
            detector: AgentDetector(),
            biometric: BiometricGate()
        )
    }

    public func clearReadCache() {
        cacheQueue.sync { readCache.removeAll() }
    }

    func invalidateCache(name: String) {
        _ = cacheQueue.sync { readCache.removeValue(forKey: name) }
    }

    @discardableResult
    public func migrateLegacyKeychain() -> (ok: Int, failed: [String]) {
        guard let migrating = store as? MigratingVaultStore else { return (0, []) }
        let result = migrating.migrateAllFromKeychain()
        clearReadCache()
        return result
    }

    public func pendingLegacyKeychainCount() -> Int {
        (store as? MigratingVaultStore)?.pendingLegacyCount() ?? 0
    }

    public func add(
        name: String, value: String, notes: String? = nil,
        expiresAt: Date? = nil, rotateEveryDays: Int? = nil, lastRotatedAt: Date? = nil,
        mcpAllowed: Bool = false,
        totpAuthURL: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date = Date(),
        revisionAction: SecretRevisionAction = .created,
        valueKind: SecretValueKind = .text
    ) throws {
        let secret = try makeSecret(
            name: name, value: value, updatedAt: updatedAt, createdAt: createdAt, notes: notes,
            expiresAt: expiresAt, rotateEveryDays: rotateEveryDays, lastRotatedAt: lastRotatedAt,
            mcpAllowed: mcpAllowed, totpAuthURL: totpAuthURL, valueKind: valueKind
        )
        try addToStore(secret, action: revisionAction)
        invalidateCache(name: name)
        try recordEvent(name: name, action: .write, projectPath: currentProjectPath())
    }

    public func update(
        name: String, value: String, notes: String? = nil,
        expiresAt: Date? = nil, rotateEveryDays: Int? = nil, lastRotatedAt: Date? = nil,
        mcpAllowed: Bool = false,
        totpAuthURL: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date = Date(),
        revisionAction: SecretRevisionAction = .updated,
        valueKind: SecretValueKind = .text
    ) throws {
        let existingCreatedAt = createdAt ?? (try? store.read(name: name).createdAt)
        let secret = try makeSecret(
            name: name, value: value, updatedAt: updatedAt, createdAt: existingCreatedAt, notes: notes,
            expiresAt: expiresAt, rotateEveryDays: rotateEveryDays, lastRotatedAt: lastRotatedAt,
            mcpAllowed: mcpAllowed, totpAuthURL: totpAuthURL, valueKind: valueKind
        )
        try updateStore(secret, action: revisionAction)
        invalidateCache(name: name)
        try recordEvent(name: name, action: .write, projectPath: currentProjectPath())
    }

    public func setMCPAllowed(name: String, allowed: Bool) async throws {
        let existing = try await read(name: name, reason: "Toggle MCP access for \(name)")
        let updated = Secret(
            name: existing.name, value: existing.value, updatedAt: Date(),
            createdAt: existing.createdAt,
            notes: existing.notes, expiresAt: existing.expiresAt,
            rotateEveryDays: existing.rotateEveryDays, lastRotatedAt: existing.lastRotatedAt,
            mcpAllowed: allowed, totpAuthURL: existing.totpAuthURL,
            valueKind: existing.valueKind
        )
        try updateStore(updated, action: .accessChanged)
        invalidateCache(name: name)
        try recordEvent(name: name, action: .write, projectPath: currentProjectPath())
    }

    public func rotate(name: String, newValue: String?) async throws {
        let existing = try await read(name: name, reason: "Rotate \(name)")
        let nextValue: String
        if let newValue {
            nextValue = try SecretJSON.prepared(raw: newValue, kind: existing.valueKind).value
        } else {
            nextValue = existing.value
        }
        let updated = Secret(
            name: existing.name, value: nextValue, updatedAt: Date(),
            createdAt: existing.createdAt,
            notes: existing.notes, expiresAt: existing.expiresAt,
            rotateEveryDays: existing.rotateEveryDays, lastRotatedAt: Date(),
            mcpAllowed: existing.mcpAllowed, totpAuthURL: existing.totpAuthURL,
            valueKind: existing.valueKind
        )
        try updateStore(updated, action: .rotated)
        invalidateCache(name: name)
        try recordEvent(name: name, action: .rotate, projectPath: currentProjectPath())
    }

    public func delete(name: String) throws {
        if let versioned = store as? VersionedSecretStoring {
            try versioned.delete(name: name, revisionAction: .deleted)
        } else {
            try store.delete(name: name)
        }
        invalidateCache(name: name)
        try recordEvent(name: name, action: .delete, projectPath: currentProjectPath())
    }

    public func read(name: String, reason: String = "Read secret") async throws -> Secret {
        try denyAgentIfBlocked(name: name)
        try await biometric.authenticate(reason: reason)
        if let cached = cacheQueue.sync(execute: { readCache[name] }) {
            do {
                try recordEvent(name: name, action: .read, projectPath: currentProjectPath())
                return cached
            } catch {
                invalidateCache(name: name)
                throw error
            }
        }
        let secret = try store.read(name: name)
        do {
            try recordEvent(name: name, action: .read, projectPath: currentProjectPath())
            cacheQueue.sync { readCache[name] = secret }
            return secret
        } catch {
            invalidateCache(name: name)
            throw error
        }
    }

    public func list() throws -> [Secret] { try store.list() }

    public func recordEvent(name: String, action: AuditEvent.Action, projectPath: String?) throws {
        let agent = detector.detect()
        try audit.record(AuditEvent(
            secretName: name, agent: agent.name, agentConfidence: agent.confidence,
            sessionId: sessionId, projectPath: projectPath, action: action
        ))
    }

    public func currentProjectPath() -> String? {
        let pwd = FileManager.default.currentDirectoryPath
        return pwd.isEmpty ? nil : pwd
    }

    func addToStore(_ secret: Secret, action: SecretRevisionAction) throws {
        if let versioned = store as? VersionedSecretStoring {
            try versioned.add(secret, revisionAction: action)
        } else {
            try store.add(secret)
        }
    }

    func updateStore(_ secret: Secret, action: SecretRevisionAction) throws {
        if let versioned = store as? VersionedSecretStoring {
            try versioned.update(secret, revisionAction: action)
        } else {
            try store.update(secret)
        }
    }
}
