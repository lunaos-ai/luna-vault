import Foundation

/// Renders secrets into dotenv (`KEY=value`) text and writes them to a file,
/// preserving any unmanaged lines already present. Values are quoted only when
/// they contain characters a shell would otherwise mangle.
public enum DotenvWriter {
    public enum Mode: Sendable {
        case merge      // keep existing unmanaged keys, update managed ones
        case overwrite  // replace the file entirely with the given secrets
    }

    public struct Result: Sendable {
        public let written: [String]
        public let path: String
        public init(written: [String], path: String) {
            self.written = written; self.path = path
        }
    }

    /// One `KEY=value` line, quoting the value when needed.
    public static func line(_ key: String, _ value: String) -> String {
        "\(key)=\(quote(value))"
    }

    static func quote(_ value: String) -> String {
        let needsQuote = value.contains(where: { " \t#\"'=$`\\".contains($0) })
            || value.contains("\n") || value.isEmpty
        guard needsQuote else { return value }
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    /// Merge `updates` into existing dotenv text: managed keys are rewritten in
    /// place, untouched lines (comments, other keys) are preserved, new keys are
    /// appended in the given order.
    public static func merge(existing: String, updates: [(String, String)]) -> String {
        let map = Dictionary(updates, uniquingKeysWith: { _, b in b })
        var done = Set<String>()
        var out: [String] = []
        for raw in existing.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let eq = raw.firstIndex(of: "=") else {
                out.append(raw); continue
            }
            let key = String(raw[..<eq]).trimmingCharacters(in: .whitespaces)
            if let v = map[key] {
                out.append(line(key, v)); done.insert(key)
            } else {
                out.append(raw)
            }
        }
        if out.last?.isEmpty == true { out.removeLast() }
        for (k, v) in updates where !done.contains(k) { out.append(line(k, v)) }
        return out.joined(separator: "\n") + "\n"
    }

    /// Atomically write secrets to `url`. In `.merge` mode existing content is
    /// preserved; in `.overwrite` mode the file is replaced.
    @discardableResult
    public static func write(
        secrets: [(name: String, value: String)],
        to url: URL,
        mode: Mode = .merge
    ) throws -> Result {
        let updates = secrets.map { ($0.name, $0.value) }
        let content: String
        switch mode {
        case .overwrite:
            content = updates.map { line($0.0, $0.1) }.joined(separator: "\n") + "\n"
        case .merge:
            let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            content = merge(existing: existing, updates: updates)
        }
        try content.data(using: .utf8)?.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return Result(written: updates.map(\.0), path: url.path)
    }
}
