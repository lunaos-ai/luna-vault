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
    /// Opt-in: after Touch ID unlock, keep vault trusted until quit or Lock.
    @Published var trustSession: Bool = false {
        didSet { applyBiometricWindow() }
    }
    /// True after a successful Unlock-for-session (cleared by Lock).
    @Published var sessionUnlocked: Bool = false
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

    static let settingsKey = "app-settings"
    var settings: AppSettings
    let prefs: PreferenceStoring

    lazy var scheduler: ExpiryScheduler = ExpiryScheduler(
        secretsProvider: { [weak self] in self?.secrets ?? [] }
    )

    let service: VaultService
    let registry: ProviderRegistry

    init(service: VaultService, registry: ProviderRegistry, prefs: PreferenceStoring = KeychainPrefs()) {
        self.service = service
        self.registry = registry
        self.prefs = prefs
        let loaded = prefs.codable(AppSettings.self, forKey: Self.settingsKey)
            ?? AppSettings.migrateLegacy(into: prefs, settingsKey: Self.settingsKey)
        self.settings = loaded
        self.biometricSessionMinutes = loaded.sessionMinutes
        self.notificationsEnabled = loaded.notificationsEnabled
        self.uiSoundsEnabled = loaded.uiSoundsEnabled
        self.warnWithinDays = loaded.warnWithinDays
        service.biometric.setSessionWindow(loaded.sessionMinutes * 60)
        Task { @MainActor [weak self] in
            self?.reloadProviderCaches()
            self?.updateSchedulerState()
        }
    }

    static func makeLive() -> AppEnvironment {
        let prefs = KeychainPrefs()
        do {
            return AppEnvironment(
                service: try VaultService.live(),
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
                registry: ProviderRegistry.defaultsWithToken(from: prefs),
                prefs: prefs
            )
        }
    }
}
