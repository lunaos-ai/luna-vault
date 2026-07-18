import Foundation

/// Appends dotenv exclusions to `.gitignore` and optionally `.cursorignore`.
public enum ProjectIgnoreAssistant {
    public static let gitignoreBlock = """
    # vibe-vault
    .env
    .env.*
    !.env.example
    !.env.sample
    """

    public static let cursorignoreBlock = """
    # vibe-vault — keep local env out of Cursor index
    .env
    .env.local
    .env.*.local
    """

    public static let marker = "# vibe-vault"

    public static func ensureGitignore(projectURL: URL) throws -> Bool {
        try ensureFile(
            at: projectURL.appendingPathComponent(".gitignore"),
            block: gitignoreBlock
        )
    }

    public static func ensureCursorignore(projectURL: URL) throws -> Bool {
        try ensureFile(
            at: projectURL.appendingPathComponent(".cursorignore"),
            block: cursorignoreBlock
        )
    }

    /// Returns true if the file was created or updated.
    public static func ensureFile(at url: URL, block: String) throws -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path),
           let existing = try? String(contentsOf: url, encoding: .utf8),
           existing.contains(marker) {
            return false
        }
        if fm.fileExists(atPath: url.path),
           let existing = try? String(contentsOf: url, encoding: .utf8) {
            let joined = existing.trimmingCharacters(in: .whitespacesAndNewlines)
                + "\n\n" + block.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            try joined.write(to: url, atomically: true, encoding: .utf8)
        } else {
            try (block.trimmingCharacters(in: .whitespacesAndNewlines) + "\n")
                .write(to: url, atomically: true, encoding: .utf8)
        }
        return true
    }
}
