import Foundation

/// Installs a lightweight pre-commit hook that blocks committing dotenv leaks.
public enum PreCommitGuard {
    public static let marker = "# vibe-vault-guard"

    public static var hookBody: String {
        """
        #!/bin/sh
        \(marker)
        # Blocks committing tracked .env files. Install: vibevault guard install
        if command -v vibevault >/dev/null 2>&1; then
          vibevault scan --git-only >/dev/null 2>&1
          status=$?
          if [ "$status" -eq 4 ]; then
            echo "vibe-vault: tracked .env files found. Untrack or add to .gitignore." >&2
            vibevault scan --git-only >&2
            exit 1
          fi
        fi
        exit 0

        """
    }

    public static func hookURL(projectURL: URL) -> URL {
        projectURL.appendingPathComponent(".git/hooks/pre-commit")
    }

    public static func isInstalled(projectURL: URL) -> Bool {
        let url = hookURL(projectURL: projectURL)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return content.contains(marker)
    }

    public static func install(projectURL: URL, fileManager: FileManager = .default) throws {
        let hooks = projectURL.appendingPathComponent(".git/hooks")
        guard fileManager.fileExists(atPath: hooks.path) else {
            throw GuardError.notAGitRepo
        }
        let url = hookURL(projectURL: projectURL)
        if let existing = try? String(contentsOf: url, encoding: .utf8),
           !existing.contains(marker) {
            let combined = existing.trimmingCharacters(in: .whitespacesAndNewlines)
                + "\n\n" + hookBody
            try combined.write(to: url, atomically: true, encoding: .utf8)
        } else {
            try hookBody.write(to: url, atomically: true, encoding: .utf8)
        }
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
    }
}

public enum GuardError: Error, CustomStringConvertible {
    case notAGitRepo
    public var description: String {
        switch self {
        case .notAGitRepo: return "not a git repository (.git/hooks missing)"
        }
    }
}
