import Foundation

extension VaultService {
    public func setTOTP(name: String, authURL: String?) async throws {
        let existing = try await read(name: name, reason: "Update MFA code for \(name)")
        let cleaned = authURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = Secret(
            name: existing.name, value: existing.value, updatedAt: Date(),
            createdAt: existing.createdAt,
            notes: existing.notes, expiresAt: existing.expiresAt,
            rotateEveryDays: existing.rotateEveryDays, lastRotatedAt: existing.lastRotatedAt,
            mcpAllowed: existing.mcpAllowed,
            totpAuthURL: cleaned?.isEmpty == false ? cleaned : nil
        )
        try updateStore(updated, action: .mfaChanged)
        invalidateCache(name: name)
        try recordEvent(name: name, action: .write, projectPath: currentProjectPath())
    }

    public func revisionSummaries(for name: String) throws -> [SecretRevisionSummary] {
        guard let versioned = store as? VersionedSecretStoring else { return [] }
        return try versioned.revisions(for: name).map(SecretRevisionSummary.init)
    }

    public func deletedSecretRevisionSummaries() throws -> [SecretRevisionSummary] {
        guard let versioned = store as? VersionedSecretStoring else { return [] }
        let latestByName = Dictionary(
            grouping: try versioned.allRevisions(),
            by: { $0.secret.name }
        ).compactMapValues { revisions in
            revisions.max(by: { $0.capturedAt < $1.capturedAt })
        }
        return latestByName.values
            .filter { $0.isDeleted && (try? store.exists(name: $0.secret.name)) != true }
            .map(SecretRevisionSummary.init)
            .sorted { $0.capturedAt > $1.capturedAt }
    }

    public func readRevision(id: UUID, name: String, reason: String = "Read secret revision") async throws -> SecretRevision {
        try await biometric.authenticate(reason: reason)
        guard let versioned = store as? VersionedSecretStoring,
              let revision = try versioned.revisions(for: name).first(where: { $0.id == id }) else {
            throw SecretError.vaultIO("revision not found: \(id.uuidString)")
        }
        try recordEvent(name: name, action: .read, projectPath: currentProjectPath())
        return revision
    }

    @discardableResult
    public func restoreRevision(id: UUID, name: String) async throws -> Secret {
        try await biometric.authenticate(reason: "Restore an earlier version of \(name)")
        guard let versioned = store as? VersionedSecretStoring else {
            throw SecretError.vaultIO("version history is unavailable for this vault")
        }
        let restored = try versioned.restoreRevision(id: id, restoredAt: Date())
        invalidateCache(name: restored.name)
        try recordEvent(name: restored.name, action: .write, projectPath: currentProjectPath())
        return restored
    }

    public func revisionsForEncryptedBackup() throws -> [SecretRevision] {
        guard let versioned = store as? VersionedSecretStoring else { return [] }
        return try versioned.allRevisions()
    }

    public func mergeRevisionsFromEncryptedBackup(_ revisions: [SecretRevision]) throws {
        guard let versioned = store as? VersionedSecretStoring else { return }
        try versioned.mergeRevisions(revisions)
    }

    public func importSecrets(_ items: [ImportItem], overwrite: Bool) throws -> ImportResult {
        var imported: [String] = []
        var updated: [String] = []
        var skipped: [String] = []
        var failed: [(String, String)] = []
        for item in items {
            do {
                if try store.exists(name: item.name) {
                    if overwrite {
                        let existing = try store.read(name: item.name)
                        try updateStore(Secret(
                            name: item.name,
                            value: item.value,
                            createdAt: existing.createdAt,
                            notes: item.notes,
                            expiresAt: existing.expiresAt,
                            rotateEveryDays: existing.rotateEveryDays,
                            lastRotatedAt: existing.lastRotatedAt,
                            mcpAllowed: existing.mcpAllowed,
                            totpAuthURL: item.totpAuthURL ?? existing.totpAuthURL
                        ), action: .imported)
                        updated.append(item.name)
                        invalidateCache(name: item.name)
                    } else {
                        skipped.append(item.name)
                        continue
                    }
                } else {
                    try addToStore(
                        Secret(name: item.name, value: item.value, notes: item.notes, totpAuthURL: item.totpAuthURL),
                        action: .imported
                    )
                    imported.append(item.name)
                    invalidateCache(name: item.name)
                }
                try recordEvent(name: item.name, action: .importEvent, projectPath: currentProjectPath())
            } catch {
                failed.append((item.name, "\(error)"))
            }
        }
        return ImportResult(imported: imported, updated: updated, skipped: skipped, failed: failed)
    }
}
