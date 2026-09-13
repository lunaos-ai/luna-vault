import Foundation

protocol LinuxSecretServiceClient: Sendable {
    var isAvailable: Bool { get }
    func lookup(account: String) throws -> Data?
    func store(account: String, key: Data) throws
    func delete(account: String) throws
}

struct UnavailableSecretServiceClient: LinuxSecretServiceClient {
    var isAvailable: Bool { false }

    func lookup(account: String) throws -> Data? { nil }

    func store(account: String, key: Data) throws {
        throw SecretError.vaultIO("secret service unavailable")
    }

    func delete(account: String) throws {}
}

final class MemorySecretServiceClient: LinuxSecretServiceClient, @unchecked Sendable {
    var isAvailable: Bool
    private var items: [String: Data] = [:]
    private let lock = NSLock()

    init(isAvailable: Bool = true) {
        self.isAvailable = isAvailable
    }

    func lookup(account: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return items[account]
    }

    func store(account: String, key: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        items[account] = key
    }

    func delete(account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        items.removeValue(forKey: account)
    }
}
