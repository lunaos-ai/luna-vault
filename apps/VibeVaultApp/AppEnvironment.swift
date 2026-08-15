import Combine
import Foundation
import VaultCore

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var secrets: [Secret] = []
    @Published var authenticatorAccounts: [AuthenticatorAccountMetadata] = []
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
    /// True while a shared, time-bounded unlock lease is active.
    @Published var trustSession: Bool = false {
        didSet { applyBiometricWindow() }
    }
    /// Shared by the app, CLI, native host, and other VibeVault processes.
    @Published var sessionUnlocked: Bool = false
    @Published var unlockSessionExpiresAt: Date?
    @Published var biometricStatus: String = "Locked"
    @Published var rotatePromptName: String?
    @Published var importStatus: String?
    @Published var onboardingOpenProjects = false
    @Published var openCloudflare = false
    @Published var openPushci = false
    /// Tab to select when Providers hub appears (survives navigation race).
    @Published var pendingProviderTab: String?
    @Published var openVaultHighlight: String?
    @Published var openAIAgents = false
    @Published var openAddSecret = false
    @Published var focusVaultSearch = false
    @Published var copySelectedSecret = false
    @Published var pendingAuthenticatorInput: String?
    @Published var toastMessage: String?
    @Published var uiSoundsEnabled: Bool = true {
        didSet {
            settings.uiSoundsEnabled = uiSoundsEnabled
            persistSettings()
        }
    }

    /// Cached Keychain flags — never re-query Keychain from SwiftUI body.
    @Published var cachedHasCloudflareToken = false
    @Published var cachedHasVercelToken = false
    @Published var cachedHasAutomaticBackupCredential = false
    @Published var cachedHasBackupRecoveryKey = false
    @Published var cachedTeamLicense: TeamLicense?

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
    @Published var automaticBackupsEnabled: Bool {
        didSet {
            settings.automaticBackupsEnabled = automaticBackupsEnabled
            persistSettings()
            updateBackupSchedulerState()
        }
    }
    @Published var backupIntervalHours: Int {
        didSet {
            settings.backupIntervalHours = backupIntervalHours
            persistSettings()
            updateBackupSchedulerState()
        }
    }
    @Published var backupRetentionCount: Int {
        didSet {
            settings.backupRetentionCount = backupRetentionCount
            persistSettings()
        }
    }
    @Published var lastManagedBackupAt: Date? {
        didSet {
            settings.lastManagedBackupAt = lastManagedBackupAt
            persistSettings()
        }
    }

    static let settingsKey = "app-settings"
    var settings: AppSettings
    let prefs: PreferenceStoring

    lazy var scheduler: ExpiryScheduler = ExpiryScheduler(
        secretsProvider: { [weak self] in self?.secrets ?? [] }
    )
    lazy var backupScheduler: CloudBackupScheduler = CloudBackupScheduler(
        lastBackupProvider: { [weak self] in self?.lastManagedBackupAt },
        backupAction: { [weak self] in
            guard let self else { return false }
            return await self.runScheduledCloudBackup()
        }
    )

    let service: VaultService
    let authenticatorService: AuthenticatorService
    let registry: ProviderRegistry

    init(
        service: VaultService, authenticatorService: AuthenticatorService,
        registry: ProviderRegistry, prefs: PreferenceStoring = KeychainPrefs()
    ) {
        self.service = service
        self.authenticatorService = authenticatorService
        self.registry = registry
        self.prefs = prefs
        var loaded = prefs.codable(AppSettings.self, forKey: Self.settingsKey)
            ?? AppSettings.migrateLegacy(into: prefs, settingsKey: Self.settingsKey)
        let durationOptions = [5.0, 15.0, 30.0, 60.0, 120.0, 240.0, 480.0]
        loaded.sessionMinutes = durationOptions.min {
            abs($0 - loaded.sessionMinutes) < abs($1 - loaded.sessionMinutes)
        } ?? 15
        self.settings = loaded
        self.biometricSessionMinutes = loaded.sessionMinutes
        self.notificationsEnabled = loaded.notificationsEnabled
        self.uiSoundsEnabled = loaded.uiSoundsEnabled
        self.warnWithinDays = loaded.warnWithinDays
        self.automaticBackupsEnabled = loaded.automaticBackupsEnabled
        self.backupIntervalHours = loaded.backupIntervalHours
        self.backupRetentionCount = loaded.backupRetentionCount
        self.lastManagedBackupAt = loaded.lastManagedBackupAt
        self.cachedHasAutomaticBackupCredential =
            prefs.data(forKey: Self.automaticBackupPassphraseKey) != nil
        self.cachedHasBackupRecoveryKey =
            prefs.data(forKey: Self.backupRecoveryKeyKey) != nil
        service.biometric.setSessionWindow(loaded.sessionMinutes * 60)
        if let status = SharedUnlockSession.status() {
            self.trustSession = true
            self.sessionUnlocked = true
            self.unlockSessionExpiresAt = status.expiresAt
            self.biometricStatus = "Unlocked until \(status.expiresAt.formatted(date: .omitted, time: .shortened))"
        }
        Task { @MainActor [weak self] in
            self?.ensureLocalRecoveryProtection()
            self?.reloadProviderCaches()
            self?.updateSchedulerState()
            self?.updateBackupSchedulerState()
        }
    }

    static func makeLive() -> AppEnvironment {
        let prefs = KeychainPrefs()
        do {
            let service = try VaultService.live()
            return AppEnvironment(
                service: service,
                authenticatorService: try AuthenticatorService(vaultService: service),
                registry: ProviderRegistry.defaultsWithToken(from: prefs),
                prefs: prefs
            )
        } catch {
            let stub = VaultService(
                store: InMemoryKeychainStore(),
                audit: NullAuditLogger(),
                detector: StubAgentDetector(),
                biometric: NoopBiometricGate()
            )
            return AppEnvironment(
                service: stub,
                authenticatorService: AuthenticatorService(
                    store: InMemoryAuthenticatorStore(), audit: stub.audit,
                    detector: stub.detector, biometric: stub.biometric,
                    sessionId: stub.sessionId
                ),
                registry: ProviderRegistry.defaultsWithToken(from: prefs),
                prefs: prefs
            )
        }
    }
}
