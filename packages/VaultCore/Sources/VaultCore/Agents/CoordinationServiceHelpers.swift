import Foundation
import CommonCrypto

/// Private utilities for the file-based coordination protocol.
enum CoordinationHelpers {
    static let base = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".luna/agents")
    static let registryDir = base.appendingPathComponent("registry")
    static let locksDir = base.appendingPathComponent("locks")
    static let inboxDir = base.appendingPathComponent("inbox")
    static let notesDir = base.appendingPathComponent("notes")
    static let staleSeconds: TimeInterval = 600

    static func sessionID() -> String {
        ProcessInfo.processInfo.environment["LUNA_SESSION"] ?? UUID().uuidString
    }

    static func agentName() -> String {
        ProcessInfo.processInfo.environment["LUNA_AGENT"] ?? "vibevault"
    }

    static func nick() -> String {
        ProcessInfo.processInfo.environment["LUNA_NICK"] ?? agentName()
    }

    static func currentDirectory() -> String {
        ProcessInfo.processInfo.environment["PWD"]
            ?? FileManager.default.currentDirectoryPath
    }

    static func ensureDirs() {
        for dir in [registryDir, locksDir, inboxDir, notesDir] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    static func sha256(_ text: String) -> String {
        let data = Data(text.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func lockURL(for repo: String) -> URL {
        locksDir.appendingPathComponent("\(sha256(repo)).json")
    }

    static func noteURL(for repo: String) -> URL {
        notesDir.appendingPathComponent("\(sha256(repo)).md")
    }

    static func isStale(_ url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let mtime = attrs[.modificationDate] as? Date
        else { return true }
        return Date().timeIntervalSince(mtime) > staleSeconds
    }

    static func readJSON(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    static func writeJSON(_ payload: [String: Any], to url: URL) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

struct StandardError: TextOutputStream {
    static var stream = StandardError()
    mutating func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}
