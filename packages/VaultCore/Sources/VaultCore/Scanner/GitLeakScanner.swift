import Foundation

/// Detects secret-bearing files tracked by git (or present when `.gitignore` omits them poorly).
public enum GitLeakScanner {
    public static let sensitivePatterns: [String] = [
        ".env", ".env.local", ".env.development", ".env.production",
        ".env.staging", ".env.test", ".env.development.local",
        ".env.production.local", ".env.staging.local",
        ".mcp.json"
    ]

    /// Relative paths of tracked files that look like dotenv leaks.
    public static func trackedLeaks(
        projectURL: URL,
        runner: (URL, [String]) throws -> String = GitLeakScanner.runGit
    ) -> [String] {
        guard isGitRepo(projectURL, runner: runner) else { return [] }
        let listed: String
        do {
            listed = try runner(projectURL, ["ls-files", "-z"])
        } catch {
            return []
        }
        let files = listed.split(separator: "\0", omittingEmptySubsequences: true).map(String.init)
        return files.filter(isSensitivePath).sorted()
    }

    public static func isSensitivePath(_ relative: String) -> Bool {
        let base = (relative as NSString).lastPathComponent
        let normalized = relative.replacingOccurrences(of: "\\", with: "/")
        if sensitivePatterns.contains(base) { return true }
        if base.hasPrefix(".env.") && !base.hasSuffix(".example") && !base.hasSuffix(".sample") {
            return true
        }
        if normalized.hasSuffix(".claude/settings.local.json") { return true }
        if normalized.hasSuffix(".cursor/mcp.json") { return true }
        return base == ".env"
    }

    public static func suggestGitignoreLines(for leaks: [String]) -> [String] {
        guard !leaks.isEmpty else { return [] }
        return [
            ".env",
            ".env.*",
            "!.env.example",
            "!.env.sample",
            ".mcp.json",
            ".cursor/mcp.json",
            ".claude/settings.local.json"
        ]
    }

    private static func isGitRepo(
        _ url: URL,
        runner: (URL, [String]) throws -> String
    ) -> Bool {
        (try? runner(url, ["rev-parse", "--is-inside-work-tree"]))?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    public static func runGit(cwd: URL, args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", cwd.path] + args
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "GitLeakScanner",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "git failed"]
            )
        }
        return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
