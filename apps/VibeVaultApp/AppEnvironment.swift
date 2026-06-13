import Combine
import Foundation
import VaultCore

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var secrets: [Secret] = []
    @Published var lastError: String?
    @Published var scanResult: ScanResult?
    @Published var isScanning: Bool = false
    @Published var lastScannedURL: URL?
    @Published var auditEvents: [AuditEvent] = []
    @Published var biometricSessionMinutes: Double {
        didSet {
            settings.sessionMinutes = biometricSessionMinutes
            persistSettings()
            applyBiometricWindow()
        }
    }
    @Published var trustSession: Bool = false {
        didSet {
            applyBiometricWindow()
            if !trustSession {
                biometricStatus = "Re-prompts every \(Int(biometricSessionMinutes)) min."
            } else {
                biometricStatus = "Trusted until app quits."
            }
        }
    }
    @Published var biometricStatus: String = "Idle"
    @Published var rotatePromptName: String?
    @Published var importStatus: String?
    @Published var notificationsEnabled: Bool {
        didSet {
            settings.notificationsEnabled = notificationsEnabled
            persistSettings()
            updateSchedulerState()
        }
    }
    @Published var warnWithinDays: Int {
        didSet {
            settings.warnWithinDays = warnWithinDays
            persistSettings()
            updateSchedulerState()
        }
    }
    @Published var lastNotifierRun: String = "Never"

    static let settingsKey = "app-settings"
    private var settings: AppSettings
    private let prefs: PreferenceStoring

    lazy var scheduler: ExpiryScheduler = ExpiryScheduler(
        secretsProvider: { [weak self] in self?.secrets ?? [] }
    )

    let service: VaultService
    let registry: ProviderRegistry
    let history: SecretHistoryWriting

    init(
        service: VaultService,
        registry: ProviderRegistry,
        prefs: PreferenceStoring = KeychainPrefs(),
        history: SecretHistoryWriting = InMemoryHistoryStore()
    ) {
        self.service = service
        self.registry = registry
        self.history = history
        self.prefs = prefs
        let loaded = prefs.codable(AppSettings.self, forKey: Self.settingsKey) ?? AppSettings.migrateLegacy(into: prefs, settingsKey: Self.settingsKey)
        self.settings = loaded
        self.biometricSessionMinutes = loaded.sessionMinutes
        self.notificationsEnabled = loaded.notificationsEnabled
        self.warnWithinDays = loaded.warnWithinDays
        service.biometric.setSessionWindow(loaded.sessionMinutes * 60)
        Task { @MainActor [weak self] in self?.updateSchedulerState() }
    }

    private func persistSettings() {
        prefs.setCodable(settings, forKey: Self.settingsKey)
    }

    private func applyBiometricWindow() {
        let seconds: TimeInterval = trustSession
            ? .greatestFiniteMagnitude
            : biometricSessionMinutes * 60
        service.biometric.setSessionWindow(seconds)
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
            return AppEnvironment(
                service: try VaultService.live(),
                registry: ProviderRegistry.defaults(),
                history: SecretHistoryStore()
            )
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
        let known = Set(secrets.map(\.name))
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
                case .success(let r): self.scanResult = r
                case .failure(let e): self.lastError = "\(e)"
                }
            }
        }
    }
}
