import Foundation

extension VaultService {
    public struct ImportItem: Sendable {
        public let name: String
        public let value: String
        public let notes: String?
        public let totpAuthURL: String?
        public let valueKind: SecretValueKind
        public init(
            name: String,
            value: String,
            notes: String? = nil,
            totpAuthURL: String? = nil,
            valueKind: SecretValueKind = .text
        ) {
            self.name = name
            self.value = value
            self.notes = notes
            self.totpAuthURL = totpAuthURL
            self.valueKind = valueKind
        }
    }

    public struct ImportResult: Sendable {
        public let imported: [String]
        public let updated: [String]
        public let skipped: [String]
        public let failed: [(String, String)]
    }

    func makeSecret(
        name: String,
        value: String,
        updatedAt: Date,
        createdAt: Date?,
        notes: String?,
        expiresAt: Date?,
        rotateEveryDays: Int?,
        lastRotatedAt: Date?,
        mcpAllowed: Bool,
        totpAuthURL: String?,
        valueKind: SecretValueKind
    ) throws -> Secret {
        let prepared = try SecretJSON.prepared(raw: value, kind: valueKind)
        return Secret(
            name: name,
            value: prepared.value,
            updatedAt: updatedAt,
            createdAt: createdAt,
            notes: notes,
            expiresAt: expiresAt,
            rotateEveryDays: rotateEveryDays,
            lastRotatedAt: lastRotatedAt,
            mcpAllowed: mcpAllowed,
            totpAuthURL: totpAuthURL,
            valueKind: prepared.kind
        )
    }

    public func updateValue(name: String, value: String, valueKind: SecretValueKind) async throws {
        let existing = try await read(name: name, reason: "Update \(name)")
        let prepared = try SecretJSON.prepared(raw: value, kind: valueKind)
        try updateStore(
            Secret(
                name: existing.name,
                value: prepared.value,
                createdAt: existing.createdAt,
                notes: existing.notes,
                expiresAt: existing.expiresAt,
                rotateEveryDays: existing.rotateEveryDays,
                lastRotatedAt: existing.lastRotatedAt,
                mcpAllowed: existing.mcpAllowed,
                totpAuthURL: existing.totpAuthURL,
                valueKind: prepared.kind
            ),
            action: .updated
        )
        invalidateCache(name: name)
        try recordEvent(name: name, action: .write, projectPath: currentProjectPath())
    }
}
