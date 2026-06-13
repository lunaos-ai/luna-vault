import Foundation
import VaultCore

/// Agent detector whose identity is the connected MCP client, learned from the
/// `initialize` handshake. Until then it reports `mcp:unknown`. This is what
/// makes the audit log attribute reads to "mcp:claude-code" / "mcp:cursor"
/// instead of a generic placeholder.
final class MCPClientDetector: AgentDetecting, @unchecked Sendable {
    private let lock = NSLock()
    private var clientName: String

    init(clientName: String = "mcp:unknown") {
        self.clientName = clientName
    }

    var name: String {
        get { lock.lock(); defer { lock.unlock() }; return clientName }
        set { lock.lock(); clientName = newValue; lock.unlock() }
    }

    func detect() -> DetectedAgent {
        DetectedAgent(name: name, confidence: .medium, source: "mcp-client")
    }
}
