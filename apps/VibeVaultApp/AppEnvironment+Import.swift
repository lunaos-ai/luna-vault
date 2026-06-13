import Foundation
import VaultCore

/// Import flows split out of AppEnvironment to keep each file under the 200 LOC cap.
@MainActor
extension AppEnvironment {
    func importDotenv(at url: URL, overwrite: Bool) {
        do {
            let items = try DotenvImporter.parseFile(at: url)
            let r = try service.importSecrets(items, overwrite: overwrite)
            importStatus = "Imported \(r.imported.count) · updated \(r.updated.count) · skipped \(r.skipped.count) · failed \(r.failed.count)"
            refresh()
        } catch {
            importStatus = "error: \(error)"
        }
    }

    func importEnv(globs: [String], overwrite: Bool) {
        importStatus = "Reading shell environment…"
        Task.detached(priority: .userInitiated) { [weak self] in
            let shellEnv = LoginShellEnv.snapshot()
            let items = EnvImporter.collect(env: shellEnv, matching: globs)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if shellEnv.isEmpty {
                    self.importStatus = "Could not read shell env. Open Terminal and run: open -a VibeVault"
                    return
                }
                if items.isEmpty {
                    self.importStatus = "No env vars matched: \(globs.joined(separator: " "))"
                    return
                }
                do {
                    let r = try self.service.importSecrets(items, overwrite: overwrite)
                    self.importStatus = "Imported \(r.imported.count) · updated \(r.updated.count) · skipped \(r.skipped.count)"
                    self.refresh()
                } catch {
                    self.importStatus = "error: \(error)"
                }
            }
        }
    }

    func importOnePassword(itemRef: String, overwrite: Bool) {
        do {
            let items = try OnePasswordImporter.fetch(itemRef: itemRef)
            let r = try service.importSecrets(items, overwrite: overwrite)
            importStatus = "Imported \(r.imported.count) · updated \(r.updated.count) · skipped \(r.skipped.count)"
            refresh()
        } catch {
            importStatus = "error: \(error)"
        }
    }

    func importMissing(projectURL: URL, missing: Set<String>, overwrite: Bool) {
        let r = ProjectMissingImporter.collect(projectURL: projectURL, missing: missing)
        if r.items.isEmpty {
            importStatus = r.stillMissing.isEmpty
                ? "No missing secrets."
                : "No .env values found for \(r.stillMissing.count) secret\(r.stillMissing.count == 1 ? "" : "s"). Add them manually or check .env.local."
            return
        }
        do {
            let res = try service.importSecrets(r.items, overwrite: overwrite)
            var msg = "Imported \(res.imported.count) · updated \(res.updated.count) · skipped \(res.skipped.count)"
            if !r.stillMissing.isEmpty {
                msg += " · \(r.stillMissing.count) without a value"
            }
            importStatus = msg
            refresh()
            if let url = lastScannedURL { scan(projectURL: url) }
        } catch {
            importStatus = "error: \(error)"
        }
    }

    func importClipboard(overwrite: Bool) {
        do {
            let items = ClipboardImporter.read()
            if items.isEmpty { importStatus = "Clipboard had nothing dotenv-shaped"; return }
            let r = try service.importSecrets(items, overwrite: overwrite)
            importStatus = "Imported \(r.imported.count) · updated \(r.updated.count) · skipped \(r.skipped.count)"
            refresh()
        } catch {
            importStatus = "error: \(error)"
        }
    }
}
