import AppKit
import Foundation
import VaultCore

/// Quick-access copy, .env export + git guard, and value history / rollback.
/// All paths go through `service.read`, so every value access is Touch ID-gated
/// and audited before it leaves the Keychain.
extension AppEnvironment {
    /// Copy a secret value to the clipboard, then auto-clear it after `clearAfter`
    /// seconds (only if the pasteboard still holds our value).
    func copyToClipboard(name: String, clearAfter: TimeInterval = 45) async {
        do {
            let secret = try await service.read(name: name, reason: "Copy \(name) to clipboard")
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(secret.value, forType: .string)
            biometricStatus = "Copied \(name). Clears in \(Int(clearAfter))s."
            let value = secret.value
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(clearAfter * 1_000_000_000))
                if NSPasteboard.general.string(forType: .string) == value {
                    NSPasteboard.general.clearContents()
                }
                _ = self
            }
        } catch {
            lastError = "\(error)"
        }
    }

    /// Read the named secrets and write them to a project `.env` file, then add a
    /// `.gitignore` entry and a pre-commit hook so they can't be committed.
    @discardableResult
    func exportEnv(
        to fileURL: URL,
        names: [String],
        mode: DotenvWriter.Mode = .merge,
        addGuard: Bool = true
    ) async -> String {
        do {
            var pairs: [(name: String, value: String)] = []
            for name in names {
                let s = try await service.read(name: name, reason: "Export \(name) to .env")
                pairs.append((s.name, s.value))
            }
            let result = try DotenvWriter.write(secrets: pairs, to: fileURL, mode: mode)
            let project = fileURL.deletingLastPathComponent()
            var notes = "Wrote \(result.written.count) secret\(result.written.count == 1 ? "" : "s")."
            if addGuard {
                _ = try? GitGuard.ensureGitignore(projectURL: project)
                if let hook = try? GitGuard.installPrecommitHook(projectURL: project) {
                    notes += hook == .skippedForeignHook
                        ? " Kept your existing pre-commit hook."
                        : " Git guard active."
                }
            }
            try? service.recordEvent(
                name: fileURL.lastPathComponent, action: .export, projectPath: project.path)
            importStatus = notes
            return notes
        } catch {
            lastError = "\(error)"
            return "Export failed: \(error)"
        }
    }

    /// Rotate a value, saving the previous value to history first.
    func rotateSaving(name: String, newValue: String) async {
        do {
            let old = try await service.read(name: name, reason: "Rotate \(name)")
            try? history.record(name: name, value: old.value)
            try await service.rotate(name: name, newValue: newValue)
            refresh()
        } catch {
            lastError = "\(error)"
        }
    }

    func historyVersions(name: String) -> [SecretVersion] {
        (try? history.versions(name: name)) ?? []
    }

    /// Restore a previous value: the current value is saved to history, then the
    /// chosen version becomes current. Audited as a rollback.
    func rollback(name: String, to version: SecretVersion) async {
        do {
            let current = try await service.read(name: name, reason: "Roll back \(name)")
            try? history.record(name: name, value: current.value)
            try await service.rotate(name: name, newValue: version.value)
            try? service.recordEvent(
                name: name, action: .rollback, projectPath: service.currentProjectPath())
            refresh()
        } catch {
            lastError = "\(error)"
        }
    }
}
