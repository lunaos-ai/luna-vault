import Foundation

/// Composes KeychainStore + AuditDB + AgentDetector + BiometricGate.
/// Every secret read goes through this façade so audit cannot be bypassed.
public final class VaultService: @unchecked Sendable {
    public let store: KeychainStoring
    public let audit: AuditLogging
    public let detector: AgentDetecting
    public let biometric: BiometricGating
    public let sessionId: String

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
            store: KeychainStore(),
            audit: try AuditDB(),
            detector: AgentDetector(),
            biometric: BiometricGate()
        )
    }

    public func add(
        name: String,
        value: String,
        notes: String? = nil,
        expiresAt: Date? = nil,
        rotateEveryDays: Int? = nil,
        mcpAllowed: Bool = false
    ) throws {
        let secret = Secret(
            name: name, value: value, notes: notes,
            expiresAt: expiresAt, rotateEveryDays: rotateEveryDays,
            mcpAllowed: mcpAllowed
        )
        try store.add(secret)
        try recordEvent(name: name, action: .write, projectPath: currentProjectPath())
    }

    public func update(
        name: String,
        value: String,
        notes: String? = nil,
        expiresAt: Date? = nil,
        rotateEveryDays: Int? = nil,
        mcpAllowed: Bool = false
    ) throws {
        let secret = Secret(
            name: name, value: value, notes: notes,
            expiresAt: expiresAt, rotateEveryDays: rotateEveryDays,
            mcpAllowed: mcpAllowed
        )
        try store.update(secret)
        try recordEvent(name: name, action: .write, projectPath: currentProjectPath())
    }

    public func setMCPAllowed(name: String, allowed: Bool) async throws {
        let existing = try await read(name: name, reason: "Toggle MCP access for \(name)")
        let updated = Secret(
            name: existing.name, value: existing.value, updatedAt: Date(),
            notes: existing.notes, expiresAt: existing.expiresAt,
            rotateEveryDays: existing.rotateEveryDays, lastRotatedAt: existing.lastRotatedAt,
            mcpAllowed: allowed
        )
        try store.update(updated)
        try recordEvent(name: name, action: .write, projectPath: currentProjectPath())
    }

    public func rotate(name: String, newValue: String?) async throws {
        let existing = try await read(name: name, reason: "Rotate \(name)")
        let updated = Secret(
            name: existing.name,
            value: newValue ?? existing.value,
            updatedAt: Date(),
            notes: existing.notes,
            expiresAt: existing.expiresAt,
            rotateEveryDays: existing.rotateEveryDays,
            lastRotatedAt: Date()
        )
        try store.update(updated)
        try recordEvent(name: name, action: .rotate, projectPath: currentProjectPath())
    }

    public struct ImportItem: Sendable {
        public let name: String
        public let value: String
        public let notes: String?
        public init(name: String, value: String, notes: String? = nil) {
            self.name = name; self.value = value; self.notes = notes
        }
    }

    public struct ImportResult: Sendable {
        public let imported: [String]
        public let updated: [String]
        public let skipped: [String]
        public let failed: [(String, String)]
    }

    public func importSecrets(_ items: [ImportItem], overwrite: Bool) throws -> ImportResult {
        var imported: [String] = []
        var updated: [String] = []
        var skipped: [String] = []
        var failed: [(String, String)] = []
        for item in items {
            do {
                if try store.exists(name: item.name) {
                    if overwrite {
                        try store.update(Secret(name: item.name, value: item.value, notes: item.notes))
                        updated.append(item.name)
                    } else {
                        skipped.append(item.name)
                        continue
                    }
                } else {
                    try store.add(Secret(name: item.name, value: item.value, notes: item.notes))
                    imported.append(item.name)
                }
                try recordEvent(name: item.name, action: .importEvent, projectPath: currentProjectPath())
            } catch {
                failed.append((item.name, "\(error)"))
            }
        }
        return ImportResult(imported: imported, updated: updated, skipped: skipped, failed: failed)
    }

    public func delete(name: String) throws {
        try store.delete(name: name)
        try recordEvent(name: name, action: .delete, projectPath: currentProjectPath())
    }

    public func read(name: String, reason: String = "Read secret") async throws -> Secret {
        try await biometric.authenticate(reason: reason)
        let secret = try store.read(name: name)
        try recordEvent(name: name, action: .read, projectPath: currentProjectPath())
        return secret
    }

    public func list() throws -> [Secret] {
        try store.list()
    }

    public func recordEvent(name: String, action: AuditEvent.Action, projectPath: String?) throws {
        let agent = detector.detect()
        let event = AuditEvent(
            secretName: name,
            agent: agent.name,
            agentConfidence: agent.confidence,
            sessionId: sessionId,
            projectPath: projectPath,
            action: action
        )
        try audit.record(event)
    }

    public func currentProjectPath() -> String? {
        let pwd = FileManager.default.currentDirectoryPath
        return pwd.isEmpty ? nil : pwd
    }
}
