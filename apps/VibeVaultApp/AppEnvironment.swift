import Combine
import Foundation
import VaultCore

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var secrets: [Secret] = []
    @Published var lastError: String?
    @Published var scanResult: ScanResult?
    @Published var auditEvents: [AuditEvent] = []
    @Published var biometricSessionMinutes: Double {
        didSet {
            UserDefaults.standard.set(biometricSessionMinutes, forKey: Self.sessionMinutesKey)
            service.biometric.setSessionWindow(biometricSessionMinutes * 60)
        }
    }
    @Published var biometricStatus: String = "Idle"
    @Published var rotatePromptName: String?
    @Published var importStatus: String?
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Self.notificationsEnabledKey)
            updateSchedulerState()
        }
    }
    @Published var warnWithinDays: Int {
        didSet {
            UserDefaults.standard.set(warnWithinDays, forKey: Self.warnWithinDaysKey)
            updateSchedulerState()
        }
    }
    @Published var lastNotifierRun: String = "Never"

    static let sessionMinutesKey = "vibe-vault.biometric.session-minutes"
    static let notificationsEnabledKey = "vibe-vault.notifications.enabled"
    static let warnWithinDaysKey = "vibe-vault.notifications.warn-within-days"

    lazy var scheduler: ExpiryScheduler = ExpiryScheduler(
        secretsProvider: { [weak self] in self?.secrets ?? [] }
    )

    let service: VaultService
    let registry: ProviderRegistry

    init(service: VaultService, registry: ProviderRegistry) {
        self.service = service
        self.registry = registry
        let stored = UserDefaults.standard.double(forKey: Self.sessionMinutesKey)
        self.biometricSessionMinutes = stored > 0 ? stored : 5
        self.notificationsEnabled = UserDefaults.standard.object(forKey: Self.notificationsEnabledKey) as? Bool ?? true
        let storedWarn = UserDefaults.standard.integer(forKey: Self.warnWithinDaysKey)
        self.warnWithinDays = storedWarn > 0 ? storedWarn : 14
        service.biometric.setSessionWindow(self.biometricSessionMinutes * 60)
        Task { @MainActor [weak self] in self?.updateSchedulerState() }
    }

    private func updateSchedulerState() {
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

    static func makeLive() -> AppEnvironment {
        do {
            return AppEnvironment(service: try VaultService.live(), registry: ProviderRegistry.defaults())
        } catch {
            let stub = VaultService(
                store: InMemoryKeychainStore(),
                audit: NullAuditLogger(),
                detector: StubAgentDetector(),
                biometric: NoopBiometricGate()
            )
            return AppEnvironment(service: stub, registry: ProviderRegistry.defaults())
        }
    }

    func resetBiometricSession() {
        service.biometric.resetSession()
        biometricStatus = "Locked. Touch ID required on next read."
    }

    func rotate(name: String, newValue: String) async {
        do {
            try await service.rotate(name: name, newValue: newValue)
            refresh()
        } catch {
            lastError = "\(error)"
        }
    }

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
        do {
            let items = EnvImporter.collect(matching: globs)
            let r = try service.importSecrets(items, overwrite: overwrite)
            importStatus = "Imported \(r.imported.count) · updated \(r.updated.count) · skipped \(r.skipped.count)"
            refresh()
        } catch {
            importStatus = "error: \(error)"
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

    func testBiometric() async {
        biometricStatus = "Waiting for Touch ID…"
        do {
            try await service.biometric.authenticate(reason: "Verify Touch ID configuration")
            biometricStatus = "Unlocked. Re-prompts in \(Int(biometricSessionMinutes)) min."
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

    func deleteSecret(name: String) {
        do { try service.delete(name: name); refresh() }
        catch { lastError = "\(error)" }
    }

    func scan(projectURL: URL) {
        do {
            let known = Set(secrets.map(\.name))
            scanResult = try ProjectScanner().scan(projectURL: projectURL, knownSecrets: known)
        } catch { lastError = "\(error)" }
    }
}
