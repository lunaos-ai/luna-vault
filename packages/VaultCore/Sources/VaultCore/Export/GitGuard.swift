import Foundation

/// Guards a project against committing the very `.env` files Vibe Vault writes.
/// Two independent layers: a `.gitignore` entry, and a pre-commit hook that
/// blocks staged dotenv files and obvious secret patterns. The hook embeds no
/// secret values — it matches by filename and well-known key prefixes only.
public enum GitGuard {
    static let marker = "# managed by vibe-vault"
    static let ignoreLines = [".env", ".env.local", ".env.*.local"]

    /// Ensure the dotenv patterns are present in `<project>/.gitignore`.
    /// Returns true if the file was changed.
    @discardableResult
    public static func ensureGitignore(projectURL: URL) throws -> Bool {
        let url = projectURL.appendingPathComponent(".gitignore")
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let present = Set(existing.split(separator: "\n").map {
            $0.trimmingCharacters(in: .whitespaces)
        })
        let missing = ignoreLines.filter { !present.contains($0) }
        guard !missing.isEmpty else { return false }
        var out = existing
        if !out.isEmpty, !out.hasSuffix("\n") { out += "\n" }
        out += "\n\(marker)\n" + missing.joined(separator: "\n") + "\n"
        try out.data(using: .utf8)?.write(to: url, options: .atomic)
        return true
    }

    /// The pre-commit hook body. Pure function so it is testable and reviewable.
    public static func precommitHookScript() -> String {
        """
        #!/usr/bin/env bash
        \(marker)
        # Block accidental commits of secret material.
        set -euo pipefail
        staged=$(git diff --cached --name-only --diff-filter=ACM)
        bad=$(echo "$staged" | grep -E '(^|/)\\.env($|\\.)' | grep -vE '\\.env\\.example$' || true)
        if [ -n "$bad" ]; then
          echo "vibe-vault: refusing to commit dotenv files:" >&2
          echo "$bad" | sed 's/^/  /' >&2
          echo "Remove them from the index: git rm --cached <file>" >&2
          exit 1
        fi
        if git diff --cached -U0 | grep -E '(sk-[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' >/dev/null; then
          echo "vibe-vault: staged diff contains a probable secret value. Commit blocked." >&2
          exit 1
        fi
        exit 0
        """
    }

    public enum HookResult: Sendable, Equatable {
        case installed
        case alreadyInstalled
        case skippedForeignHook  // a non-vibe-vault hook already exists
    }

    /// Install the pre-commit hook into `<project>/.git/hooks`. Never clobbers a
    /// foreign hook the user already wrote.
    @discardableResult
    public static func installPrecommitHook(projectURL: URL) throws -> HookResult {
        let hooks = projectURL.appendingPathComponent(".git/hooks", isDirectory: true)
        try FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: true)
        let hook = hooks.appendingPathComponent("pre-commit")
        if let current = try? String(contentsOf: hook, encoding: .utf8) {
            if current.contains(marker) { return .alreadyInstalled }
            return .skippedForeignHook
        }
        try precommitHookScript().data(using: .utf8)?.write(to: hook, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hook.path)
        return .installed
    }
}
