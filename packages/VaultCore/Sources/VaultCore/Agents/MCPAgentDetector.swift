import Foundation

public final class MCPAgentDetector: AgentDetecting, @unchecked Sendable {
    private let fallback: AgentDetector
    private let lock = NSLock()
    private var clientCanonical: String?

    public init(env: [String: String] = ProcessInfo.processInfo.environment) {
        self.fallback = AgentDetector(env: env)
    }

    public func setMCPClientName(_ raw: String) {
        lock.lock()
        clientCanonical = MCPClientMapper.canonical(from: raw)
        lock.unlock()
    }

    public func detect() -> DetectedAgent {
        lock.lock()
        let client = clientCanonical
        lock.unlock()
        if let client {
            return DetectedAgent(name: client, confidence: .high, source: "mcp-initialize")
        }
        return fallback.detect()
    }
}
