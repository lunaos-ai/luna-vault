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

    public func add(name: String, value: String, notes: String? = nil) throws {
        let secret = Secret(name: name, value: value, notes: notes)
        try store.add(secret)
        try recordEvent(name: name, action: .write, projectPath: currentProjectPath())
    }

    public func update(name: String, value: String, notes: String? = nil) throws {
        let secret = Secret(name: name, value: value, notes: notes)
        try store.update(secret)
        try recordEvent(name: name, action: .write, projectPath: currentProjectPath())
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
