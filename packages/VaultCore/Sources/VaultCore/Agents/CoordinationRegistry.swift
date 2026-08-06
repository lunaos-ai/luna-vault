import Foundation

/// Auto-registers a running agent session so peers can discover it and avoid
/// overwriting work on the same repo or dependency worktree.
public final class CoordinationRegistry: @unchecked Sendable {
    public static let `default` = CoordinationRegistry()

    private let sessionId: String
    private let agent: String
    private let baseURL: URL
    private let interval: UInt64
    private var task: Task<Void, Never>?
    private let queue = DispatchQueue(label: "dev.vibevault.coordination")

    public init(
        sessionId: String? = nil,
        agent: String? = nil,
        heartbeatSeconds: UInt64 = 300
    ) {
        let sid = sessionId?.isEmpty == false
            ? sessionId!
            : ProcessInfo.processInfo.environment["LUNA_SESSION"]
        let resolvedSession = sid?.isEmpty == false ? sid! : UUID().uuidString
        self.sessionId = resolvedSession
        self.agent = agent?.isEmpty == false
            ? agent!
            : ProcessInfo.processInfo.environment["LUNA_AGENT"] ?? "vibevault-mcp"
        self.baseURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".luna/agents")
        self.interval = heartbeatSeconds * 1_000_000_000
    }

    public func register(
        repo: String? = nil,
        worktree: String? = nil,
        capabilities: [String] = ["read", "write", "scan", "audit", "push", "pull"]
    ) {
        let repoPath = repo ?? currentDirectory()
        let worktreePath = worktree ?? repoPath
        queue.sync {
            try? FileManager.default.createDirectory(
                at: registryURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            writeEntry(repo: repoPath, worktree: worktreePath, capabilities: capabilities)
            startHeartbeat(repo: repoPath, worktree: worktreePath, capabilities: capabilities)
        }
    }

    public func unregister() {
        queue.sync {
            task?.cancel()
            task = nil
            try? FileManager.default.removeItem(at: registryURL)
        }
    }

    private var registryURL: URL {
        baseURL.appendingPathComponent("registry/\(sessionId).json")
    }

    private func currentDirectory() -> String {
        ProcessInfo.processInfo.environment["PWD"]
            ?? FileManager.default.currentDirectoryPath
    }

    private func startHeartbeat(repo: String, worktree: String, capabilities: [String]) {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self?.interval ?? 300_000_000_000)
                guard !Task.isCancelled else { return }
                self?.queue.sync {
                    self?.writeEntry(repo: repo, worktree: worktree, capabilities: capabilities)
                }
            }
        }
    }

    private func writeEntry(repo: String, worktree: String, capabilities: [String]) {
        let fmt = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "sessionId": sessionId,
            "agent": agent,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "repo": repo,
            "worktree": worktree,
            "capabilities": capabilities,
            "startTime": fmt.string(from: Date())
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {

            return
        }
        do {
            try data.write(to: registryURL, options: .atomic)

        } catch {

        }
    }

    deinit {
        unregister()
    }
}
