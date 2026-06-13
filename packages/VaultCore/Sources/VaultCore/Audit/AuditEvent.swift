import Foundation

public enum AgentConfidence: String, Codable, Sendable {
    case high      // matched LUNA_AGENT env explicitly
    case medium    // detected via parent process name
    case low       // fallback / unknown
}

public struct AuditEvent: Equatable, Hashable, Sendable, Identifiable {
    public let id: Int64
    public let secretName: String
    public let agent: String
    public let agentConfidence: AgentConfidence
    public let sessionId: String
    public let projectPath: String?
    public let action: Action
    /// Whether the requester was granted access. `false` records a denied read
    /// (biometric declined / unavailable) so refusals are auditable, not silent.
    public let granted: Bool
    public let timestamp: Date

    public enum Action: String, Codable, Sendable {
        case read, write, delete, push, pull, scan, rotate, importEvent = "import", expire
    }

    public init(
        id: Int64 = 0,
        secretName: String,
        agent: String,
        agentConfidence: AgentConfidence,
        sessionId: String,
        projectPath: String?,
        action: Action,
        granted: Bool = true,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.secretName = secretName
        self.agent = agent
        self.agentConfidence = agentConfidence
        self.sessionId = sessionId
        self.projectPath = projectPath
        self.action = action
        self.granted = granted
        self.timestamp = timestamp
    }
}

public struct AuditFilter: Sendable {
    public var agent: String?
    public var secretName: String?
    public var projectPath: String?
    public var action: AuditEvent.Action?
    public var granted: Bool?
    public var since: Date?
    public var limit: Int

    public init(
        agent: String? = nil,
        secretName: String? = nil,
        projectPath: String? = nil,
        action: AuditEvent.Action? = nil,
        granted: Bool? = nil,
        since: Date? = nil,
        limit: Int = 500
    ) {
        self.agent = agent
        self.secretName = secretName
        self.projectPath = projectPath
        self.action = action
        self.granted = granted
        self.since = since
        self.limit = limit
    }
}
