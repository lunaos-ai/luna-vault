import Combine
import Foundation
import VaultCore

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var secrets: [Secret] = []
    @Published var lastError: String?
    @Published var scanResult: ScanResult?
    @Published var auditEvents: [AuditEvent] = []
    @Published var biometricSessionMinutes: Double = 5

    let service: VaultService
    let registry: ProviderRegistry

    init(service: VaultService, registry: ProviderRegistry) {
        self.service = service
        self.registry = registry
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

    func refresh() {
        do { secrets = try service.list().sorted { $0.name < $1.name } }
        catch { lastError = "\(error)" }
    }

    func refreshAudit(filter: AuditFilter = AuditFilter()) {
        do { auditEvents = try service.audit.query(filter) }
        catch { lastError = "\(error)" }
    }

    func addSecret(name: String, value: String, notes: String?) {
        do { try service.add(name: name, value: value, notes: notes); refresh() }
        catch { lastError = "\(error)" }
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

final class InMemoryKeychainStore: KeychainStoring, @unchecked Sendable {
    private var items: [String: Secret] = [:]
    func add(_ secret: Secret) throws {
        if items[secret.name] != nil { throw SecretError.duplicate(name: secret.name) }
        items[secret.name] = secret
    }
    func update(_ secret: Secret) throws {
        guard items[secret.name] != nil else { throw SecretError.notFound(name: secret.name) }
        items[secret.name] = secret
    }
    func read(name: String) throws -> Secret {
        guard let s = items[name] else { throw SecretError.notFound(name: name) }
        return s
    }
    func delete(name: String) throws {
        guard items.removeValue(forKey: name) != nil else { throw SecretError.notFound(name: name) }
    }
    func list() throws -> [Secret] { Array(items.values) }
    func exists(name: String) throws -> Bool { items[name] != nil }
}

final class NullAuditLogger: AuditLogging, @unchecked Sendable {
    func record(_ event: AuditEvent) throws {}
    func query(_ filter: AuditFilter) throws -> [AuditEvent] { [] }
    func purge(olderThan: Date) throws -> Int { 0 }
}
