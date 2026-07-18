import Foundation
import VaultCore

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

    func importMissing(projectURL: URL, missing: Set<String>, overwrite: Bool, prefix: String = "") {
        let r = ProjectMissingImporter.collect(projectURL: projectURL, missing: missing, prefix: prefix)
        if r.items.isEmpty {
            importStatus = r.stillMissing.isEmpty
                ? "No missing secrets."
                : "No values found in project dotenv for: \(r.stillMissing.sorted().joined(separator: ", "))"
            return
        }
        do {
            let res = try service.importSecrets(r.items, overwrite: overwrite)
            var msg = "Imported \(res.imported.count) · updated \(res.updated.count) · skipped \(res.skipped.count)"
            if !r.stillMissing.isEmpty { msg += " · no value for \(r.stillMissing.count)" }
            importStatus = msg
            refresh()
            if let url = lastScannedURL { scan(projectURL: url) }
        } catch {
            importStatus = "error: \(error)"
        }
    }

    @discardableResult
    func importReviewed(
        items: [VaultService.ImportItem],
        overwrite: Bool,
        projectURL: URL
    ) throws -> VaultService.ImportResult {
        guard !items.isEmpty else {
            importStatus = "No secrets selected."
            throw ImportReviewError.noSelection
        }
        let res = try service.importSecrets(items, overwrite: overwrite)
        importStatus = "Imported \(res.imported.count) · updated \(res.updated.count) · skipped \(res.skipped.count)"
        refresh()
        scan(projectURL: projectURL)
        return res
    }

    func importClipboard(overwrite: Bool) {
        do {
            let items = ClipboardImporter.read()
            if items.isEmpty { importStatus = "Clipboard had nothing dotenv-shaped"; return }
            let r = try importItems(items, overwrite: overwrite)
            importStatus = "Imported \(r.imported.count) · updated \(r.updated.count) · skipped \(r.skipped.count)"
        } catch {
            importStatus = "error: \(error)"
        }
    }

    @discardableResult
    func importItems(_ items: [VaultService.ImportItem], overwrite: Bool) throws -> VaultService.ImportResult {
        let r = try service.importSecrets(items, overwrite: overwrite)
        refresh()
        return r
    }

    func scan(projectURL: URL) {
        let known = knownSecretNames(for: projectURL)
        scanResult = nil
        isScanning = true
        lastScannedURL = projectURL
        Task.detached(priority: .userInitiated) { [weak self] in
            let result: Result<ScanResult, Error>
            do {
                let scan = try ProjectScanner().scan(projectURL: projectURL, knownSecrets: known)
                result = .success(scan)
            } catch {
                result = .failure(error)
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isScanning = false
                switch result {
                case .success(let r):
                    self.scanResult = r
                    self.updateCloudflareScope(from: projectURL)
                case .failure(let e): self.lastError = "\(e)"
                }
            }
        }
    }

    var needsOnboarding: Bool { !settings.hasCompletedOnboarding }

    func completeOnboarding(openProjects: Bool = false) {
        settings.hasCompletedOnboarding = true
        persistSettings()
        if openProjects { onboardingOpenProjects = true }
    }

    /// Treats `MYPROJECT_CF_TOKEN` as satisfying scan requirement `CF_TOKEN` for that project.
    func knownSecretNames(for projectURL: URL) -> Set<String> {
        let prefix = SecretNaming.defaultProjectPrefix(from: projectURL)
        var known = Set(secrets.map(\.name))
        guard !prefix.isEmpty else { return known }
        for secret in secrets where secret.name.hasPrefix(prefix) {
            known.insert(String(secret.name.dropFirst(prefix.count)))
        }
        return known
    }
}

enum ImportReviewError: LocalizedError {
    case noSelection
    var errorDescription: String? { "No secrets selected." }
}
