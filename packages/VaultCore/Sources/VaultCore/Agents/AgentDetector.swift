import Foundation
#if canImport(Darwin)
import Darwin
#endif

public struct DetectedAgent: Equatable, Sendable {
    public let name: String
    public let confidence: AgentConfidence
    public let source: String

    public init(name: String, confidence: AgentConfidence, source: String) {
        self.name = name
        self.confidence = confidence
        self.source = source
    }
}

public protocol AgentDetecting: Sendable {
    func detect() -> DetectedAgent
}

public final class AgentDetector: AgentDetecting, @unchecked Sendable {
    public static let knownAgents: [String: String] = [
        "claude": "claude-code",
        "claude-code": "claude-code",
        "cursor": "cursor",
        "cursor-agent": "cursor",
        "windsurf": "windsurf",
        "cody": "sourcegraph-cody",
        "aider": "aider",
        "node": "node",
        "python": "python",
        "python3": "python",
        "bun": "bun",
        "deno": "deno"
    ]

    private let env: [String: String]
    private let parentProcessLookup: () -> String?

    public init(
        env: [String: String] = ProcessInfo.processInfo.environment,
        parentProcessLookup: @escaping () -> String? = AgentDetector.lookupParentProcess
    ) {
        self.env = env
        self.parentProcessLookup = parentProcessLookup
    }

    public func detect() -> DetectedAgent {
        if let explicit = env["LUNA_AGENT"], !explicit.isEmpty {
            return DetectedAgent(name: explicit, confidence: .high, source: "LUNA_AGENT")
        }
        if let parent = parentProcessLookup() {
            let lower = parent.lowercased()
            let key = (lower as NSString).lastPathComponent
            if let mapped = Self.knownAgents[key] {
                return DetectedAgent(name: mapped, confidence: .medium, source: "parent-process:\(key)")
            }
            return DetectedAgent(name: key, confidence: .low, source: "parent-process:\(key)")
        }
        return DetectedAgent(name: "unknown", confidence: .low, source: "fallback")
    }

    public static func lookupParentProcess() -> String? {
        #if canImport(Darwin)
        let ppid = getppid()
        var buffer = [CChar](repeating: 0, count: 4096)
        let size = proc_pidpath(ppid, &buffer, UInt32(buffer.count))
        guard size > 0 else { return nil }
        return String(cString: buffer)
        #else
        return nil
        #endif
    }
}

#if canImport(Darwin)
@_silgen_name("proc_pidpath")
private func proc_pidpath(_ pid: Int32, _ buffer: UnsafeMutablePointer<CChar>, _ buffersize: UInt32) -> Int32
#endif

public final class StubAgentDetector: AgentDetecting, @unchecked Sendable {
    private let fixed: DetectedAgent
    public init(_ fixed: DetectedAgent = DetectedAgent(name: "test", confidence: .high, source: "stub")) {
        self.fixed = fixed
    }
    public func detect() -> DetectedAgent { fixed }
}

public enum SessionID {
    public static func current() -> String {
        if let s = ProcessInfo.processInfo.environment["LUNA_SESSION"], !s.isEmpty { return s }
        return UUID().uuidString
    }
}
