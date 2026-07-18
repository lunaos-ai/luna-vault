import Foundation
import VaultCore

extension AppEnvironment {
    func persistSettings() {
        prefs.setCodable(settings, forKey: Self.settingsKey)
    }

    func applyBiometricWindow() {
        let seconds: TimeInterval = trustSession
            ? .greatestFiniteMagnitude
            : biometricSessionMinutes * 60
        service.biometric.setSessionWindow(seconds)
    }

    func updateSchedulerState() {
        if notificationsEnabled {
            scheduler.start(intervalMinutes: 60, warnWithinDays: warnWithinDays)
        } else {
            scheduler.stop()
        }
    }

    func runExpiryCheckNow() async {
        await scheduler.runOnce(warnWithinDays: warnWithinDays)
        if let last = scheduler.lastRunAt {
            lastNotifierRun = "\(scheduler.lastAlertCount) alert\(scheduler.lastAlertCount == 1 ? "" : "s") at \(last.formatted(date: .omitted, time: .standard))"
        }
    }

    func resetNotificationDedupe() {
        scheduler.resetDedupe()
    }

    func legacyKeychainCount() -> Int {
        service.pendingLegacyKeychainCount()
    }

    /// One Touch ID (or device password), then reveal/copy without re-prompt until quit.
    func unlockForSession() async {
        biometricStatus = "Waiting for Touch ID…"
        do {
            try await service.biometric.authenticate(reason: "Unlock Vibe Vault for this session")
            trustSession = true
            sessionUnlocked = true
            applyBiometricWindow()
            biometricStatus = "Unlocked until quit"
            showToast("Session unlocked", feedback: .success)
        } catch {
            biometricStatus = "Unlock failed"
            lastError = "\(error)"
            showToast("Unlock failed", feedback: .caution)
        }
    }

    /// Clears biometric session trust and cached secret values.
    func lockSession() {
        trustSession = false
        sessionUnlocked = false
        service.biometric.resetSession()
        service.clearReadCache()
        applyBiometricWindow()
        biometricStatus = "Locked"
        showToast("Session locked", feedback: .tick)
    }

    func resetBiometricSession() {
        lockSession()
    }

    func rotate(name: String, newValue: String) async {
        do {
            try await service.rotate(name: name, newValue: newValue)
            refresh()
        } catch {
            lastError = "\(error)"
        }
    }

    func testBiometric() async {
        biometricStatus = "Waiting for Touch ID…"
        do {
            try await service.biometric.authenticate(reason: "Verify Touch ID configuration")
            if trustSession && sessionUnlocked {
                biometricStatus = "Unlocked until quit"
            } else {
                biometricStatus = "Unlocked. Re-prompts in \(Int(biometricSessionMinutes)) min."
            }
        } catch {
            biometricStatus = "Failed: \(error)"
        }
    }

    func refresh() {
        do { secrets = try service.list().sorted { $0.name < $1.name } }
        catch { lastError = "\(error)" }
    }

    func refreshAudit(filter: AuditFilter = AuditFilter()) {
        do { auditEvents = try service.audit.query(filter) }
        catch { lastError = "\(error)" }
    }

    func addSecret(
        name: String, value: String, notes: String?,
        expiresAt: Date? = nil, rotateEveryDays: Int? = nil,
        mcpAllowed: Bool = false
    ) {
        do {
            try service.add(name: name, value: value, notes: notes,
                            expiresAt: expiresAt, rotateEveryDays: rotateEveryDays,
                            mcpAllowed: mcpAllowed)
            refresh()
        } catch { lastError = "\(error)" }
    }

    func setMCPAllowed(name: String, allowed: Bool) async {
        do {
            try await service.setMCPAllowed(name: name, allowed: allowed)
            refresh()
        } catch { lastError = "\(error)" }
    }

    /// Bulk enable or revoke MCP (`mcpAllowed`) for many secrets, then refresh + toast.
    func setMCPAllowed(for names: Set<String>, allowed: Bool) async {
        guard !names.isEmpty else { return }
        var failed = 0
        for name in names {
            do { try await service.setMCPAllowed(name: name, allowed: allowed) }
            catch { failed += 1; lastError = "\(error)" }
        }
        refresh()
        let ok = names.count - failed
        guard ok > 0 else {
            showToast("Could not update AI access", feedback: .caution)
            return
        }
        let verb = allowed ? "Allowed" : "Revoked"
        let suffix = ok == 1 ? "1 secret" : "\(ok) secrets"
        showToast("\(verb) AI access for \(suffix)", feedback: failed == 0 ? .success : .caution)
    }

    func deleteSecret(name: String) {
        do { try service.delete(name: name); refresh() }
        catch { lastError = "\(error)" }
    }

    func projectPrefix(for url: URL) -> String {
        let path = url.standardizedFileURL.path
        if let saved = settings.projectPrefixes[path], !saved.isEmpty { return saved }
        return SecretNaming.defaultProjectPrefix(from: url)
    }

    func saveProjectPrefix(_ prefix: String, for url: URL) {
        settings.projectPrefixes[url.standardizedFileURL.path] = prefix
        persistSettings()
    }

    func focusVault(secretName: String) {
        openVaultHighlight = secretName
    }

    func allowMCPAccess(for names: Set<String>) async {
        await setMCPAllowed(for: names, allowed: true)
    }
}
