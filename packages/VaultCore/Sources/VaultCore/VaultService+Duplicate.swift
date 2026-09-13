import Foundation

extension VaultService {
    /// Copies a secret to `{name}-copy` (or `-copy-2` if taken). AI access starts off.
    @discardableResult
    public func duplicate(name: String) async throws -> String {
        let existing = try await read(name: name, reason: "Duplicate \(name)")
        let taken = Set(try list().map(\.name))
        let newName = SecretNaming.copyName(of: existing.name, taken: taken)
        try add(
            name: newName,
            value: existing.value,
            notes: existing.notes,
            expiresAt: existing.expiresAt,
            rotateEveryDays: existing.rotateEveryDays,
            mcpAllowed: false,
            totpAuthURL: existing.totpAuthURL
        )
        return newName
    }
}
