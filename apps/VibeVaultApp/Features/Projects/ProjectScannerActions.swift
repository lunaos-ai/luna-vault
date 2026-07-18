import Foundation
import VaultCore

@MainActor
enum ProjectScannerActions {
    static func installGuard(projectURL: URL, env: AppEnvironment) {
        do {
            try PreCommitGuard.install(projectURL: projectURL)
            env.showToast("Pre-commit guard installed")
        } catch {
            env.lastError = "\(error)"
        }
    }

    static func fixIgnores(projectURL: URL, env: AppEnvironment) {
        do {
            _ = try ProjectIgnoreAssistant.ensureGitignore(projectURL: projectURL)
            _ = try ProjectIgnoreAssistant.ensureCursorignore(projectURL: projectURL)
            env.showToast("Updated .gitignore and .cursorignore")
        } catch {
            env.lastError = "\(error)"
        }
    }
}
