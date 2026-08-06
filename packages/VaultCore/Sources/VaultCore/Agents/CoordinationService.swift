import Foundation

/// File-based coordination primitives used by the `vibevault agent` command.
public enum CoordinationService {
    public static func register(
        repo: String? = nil,
        worktree: String? = nil,
        nick: String? = nil,
        capabilities: [String] = ["read", "write", "scan", "audit", "push", "pull"]
    ) {
        CoordinationHelpers.ensureDirs()
        let fmt = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "sessionId": CoordinationHelpers.sessionID(),
            "agent": CoordinationHelpers.agentName(),
            "nick": nick ?? CoordinationHelpers.nick(),
            "pid": ProcessInfo.processInfo.processIdentifier,
            "repo": repo ?? CoordinationHelpers.currentDirectory(),
            "worktree": worktree ?? (repo ?? CoordinationHelpers.currentDirectory()),
            "capabilities": capabilities,
            "startTime": fmt.string(from: Date())
        ]
        CoordinationHelpers.writeJSON(payload, to: CoordinationHelpers.registryDir.appendingPathComponent("\(CoordinationHelpers.sessionID()).json"))
        print(CoordinationHelpers.sessionID())
    }

    public static func peers(repo: String? = nil) {
        CoordinationHelpers.ensureDirs()
        let urls = (try? FileManager.default.contentsOfDirectory(at: CoordinationHelpers.registryDir, includingPropertiesForKeys: nil)) ?? []
        var found = false
        for url in urls.sorted(by: { $0.path < $1.path }) where url.pathExtension == "json" {
            if CoordinationHelpers.isStale(url) { continue }
            guard let dict = CoordinationHelpers.readJSON(url),
                  let sid = dict["sessionId"] as? String,
                  let agent = dict["agent"] as? String,
                  let sessionRepo = dict["repo"] as? String
            else { continue }
            if let repo = repo, sessionRepo != repo { continue }
            let nick = dict["nick"] as? String ?? agent
            let caps = (dict["capabilities"] as? [String]) ?? []
            print([sid, nick, agent, sessionRepo, caps.joined(separator: ",")].joined(separator: "\t"))
            found = true
        }
        if !found { print("(no active peers)") }
    }

    public static func lock(repo: String) -> Bool {
        CoordinationHelpers.ensureDirs()
        let url = CoordinationHelpers.lockURL(for: repo)
        if FileManager.default.fileExists(atPath: url.path), !CoordinationHelpers.isStale(url) {
            if let dict = CoordinationHelpers.readJSON(url), let holder = dict["sessionId"] as? String, holder == CoordinationHelpers.sessionID() {
                print("already locked by \(holder)")
                return true
            }
            if let dict = CoordinationHelpers.readJSON(url), let holder = dict["sessionId"] as? String, let since = dict["since"] as? String {
                print("locked by \(holder) since \(since)", to: &StandardError.stream)
            } else {
                print("locked by another session", to: &StandardError.stream)
            }
            return false
        }
        let fmt = ISO8601DateFormatter()
        CoordinationHelpers.writeJSON([
            "sessionId": CoordinationHelpers.sessionID(),
            "repo": repo,
            "since": fmt.string(from: Date())
        ], to: url)
        print("locked")
        return true
    }

    public static func unlock(repo: String) -> Bool {
        let url = CoordinationHelpers.lockURL(for: repo)
        if !FileManager.default.fileExists(atPath: url.path) {
            print("not locked")
            return true
        }
        if let dict = CoordinationHelpers.readJSON(url), let holder = dict["sessionId"] as? String, holder != CoordinationHelpers.sessionID() {
            print("locked by \(holder); refusing unlock", to: &StandardError.stream)
            return false
        }
        try? FileManager.default.removeItem(at: url)
        print("unlocked")
        return true
    }

    public static func ask(to: String, repo: String, task: String, constraints: [String: String] = [:]) {
        CoordinationHelpers.ensureDirs()
        let id = UUID().uuidString
        let fmt = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "type": "request",
            "id": id,
            "from": CoordinationHelpers.sessionID(),
            "task": task,
            "repo": repo,
            "constraints": constraints,
            "timestamp": fmt.string(from: Date())
        ]
        let targetDir = CoordinationHelpers.inboxDir.appendingPathComponent(to)
        try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        let target = targetDir.appendingPathComponent("\(id).json")
        CoordinationHelpers.writeJSON(payload, to: target)
        print(target.path)
    }

    public static func poll(from: String?, timeout: Int) async {
        CoordinationHelpers.ensureDirs()
        let inbox = CoordinationHelpers.inboxDir.appendingPathComponent(CoordinationHelpers.sessionID())
        let deadline = Date().addingTimeInterval(TimeInterval(timeout))
        while true {
            let urls = (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? []
            for url in urls.sorted(by: { $0.path < $1.path }) where url.pathExtension == "json" {
                guard let dict = CoordinationHelpers.readJSON(url), dict["type"] as? String == "response" else { continue }
                if let from = from, (dict["from"] as? String) != from { continue }
                if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                    print(text)
                }
                try? FileManager.default.removeItem(at: url)
                return
            }
            if Date() >= deadline {
                print("(timeout)")
                return
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }

    public static func note(repo: String, text: String) {
        CoordinationHelpers.ensureDirs()
        let url = CoordinationHelpers.noteURL(for: repo)
        let fmt = ISO8601DateFormatter()
        let line = "- **\(fmt.string(from: Date()))** · `\(CoordinationHelpers.sessionID())`: \(text)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path), let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url, options: .atomic)
        }
        print(url.path)
    }

    public static func notes(repo: String) {
        CoordinationHelpers.ensureDirs()
        let url = CoordinationHelpers.noteURL(for: repo)
        if !FileManager.default.fileExists(atPath: url.path) {
            print("(no notes)")
            return
        }
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            print(content, terminator: "")
        }
    }

    public static func cleanup() {
        CoordinationHelpers.ensureDirs()
        var removed = 0
        for dir in [CoordinationHelpers.registryDir, CoordinationHelpers.locksDir] {
            let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for url in urls where url.pathExtension == "json" && CoordinationHelpers.isStale(url) {
                try? FileManager.default.removeItem(at: url)
                removed += 1
            }
        }
        print("removed \(removed) stale entries")
    }
}
