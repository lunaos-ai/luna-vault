import AppKit
import SwiftUI
import XCTest
@testable import VibeVaultApp
@testable import VaultCore

/// In-memory preference store so smoke tests never touch the real Keychain.
final class MemPrefs: PreferenceStoring, @unchecked Sendable {
    private var store: [String: Data] = [:]
    func data(forKey key: String) -> Data? { store[key] }
    func set(_ data: Data?, forKey key: String) {
        if let data { store[key] = data } else { store[key] = nil }
    }
    func removeAll() { store.removeAll() }
}

@MainActor
enum Smoke {
    /// Fully stubbed environment: no Keychain, no audit DB, no Touch ID.
    static func env(secrets: [Secret] = sampleSecrets, scan: ScanResult? = nil) -> AppEnvironment {
        let service = VaultService(
            store: InMemoryKeychainStore(),
            audit: NullAuditLogger(),
            detector: StubAgentDetector(),
            biometric: NoopBiometricGate()
        )
        for s in secrets { try? service.add(name: s.name, value: s.value, notes: s.notes,
                                            expiresAt: s.expiresAt, rotateEveryDays: s.rotateEveryDays,
                                            mcpAllowed: s.mcpAllowed) }
        let prefs = MemPrefs()
        var settings = AppSettings()
        settings.notificationsEnabled = false
        prefs.setCodable(settings, forKey: AppEnvironment.settingsKey)
        let env = AppEnvironment(service: service, registry: ProviderRegistry.defaults(), prefs: prefs)
        env.refresh()
        env.scanResult = scan
        return env
    }

    static func nav() -> Navigator { Navigator() }

    nonisolated static let sampleSecrets: [Secret] = [
        Secret(name: "API_KEY", value: "sk-live-abcdef123456", notes: "primary key", mcpAllowed: true),
        Secret(name: "DATABASE_URL", value: "postgres://u:p@host/db",
               expiresAt: Date().addingTimeInterval(86_400 * 3), rotateEveryDays: 30),
        Secret(name: "STRIPE_SECRET", value: "rk_test_0000")
    ]

    nonisolated static let sampleScan = ScanResult(
        required: ["API_KEY", "DATABASE_URL", "MISSING_ONE"],
        missing: ["MISSING_ONE"],
        extra: ["STRIPE_SECRET"],
        sources: [".env": ["API_KEY", "DATABASE_URL"]]
    )

    /// Forces SwiftUI to evaluate `body` by hosting the view and laying it out.
    /// Throwing nothing and not crashing IS the assertion ("does it render").
    static func render<V: View>(_ view: V, file: StaticString = #filePath, line: UInt = #line) {
        autoreleasepool {
            // Inject the shared app-wide objects so any view (including cloud and
            // settings screens that read them) renders without a missing-object crash.
            let configured = view
                .environmentObject(ThemeManager.shared)
                .environmentObject(CloudAuthService.shared)
                .environmentObject(CloudBackupService.shared)
                .environmentObject(IAPManager.shared)
            let host = NSHostingView(rootView: configured.frame(width: 900, height: 640))
            host.frame = NSRect(x: 0, y: 0, width: 900, height: 640)
            let window = NSWindow(
                contentRect: host.frame,
                styleMask: [.titled], backing: .buffered, defer: true
            )
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            XCTAssertNotNil(host.rootView, file: file, line: line)
            window.contentView = nil
        }
    }
}
