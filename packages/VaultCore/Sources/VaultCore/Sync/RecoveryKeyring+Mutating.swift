import Foundation

public enum RecoveryKeyringError: Error, Equatable, CustomStringConvertible {
    case cannotRemoveActive
    case keyNotFound

    public var description: String {
        switch self {
        case .cannotRemoveActive:
            return "the active recovery key cannot be removed; stop using it for new backups first"
        case .keyNotFound:
            return "that recovery key is not installed"
        }
    }
}

extension RecoveryKeyring {
    public mutating func addRetained(_ key: String, at date: Date = Date()) throws {
        let record = try makeRecord(key, at: date, imported: true, role: .retained)
        if records.contains(where: { $0.identifier == record.identifier }) {
            return
        }
        records.append(record)
        sortRecords()
    }

    public mutating func makeActive(_ key: String, at date: Date = Date(), imported: Bool = false) throws {
        let incoming = try makeRecord(key, at: date, imported: imported, role: .active)
        if let index = records.firstIndex(where: { $0.identifier == incoming.identifier }) {
            demoteActive()
            records[index].role = .active
            sortRecords()
            return
        }
        demoteActive()
        records.insert(incoming, at: 0)
        sortRecords()
    }

    public mutating func clearActive() {
        demoteActive()
        sortRecords()
    }

    public mutating func removeRetained(identifier: String) throws {
        guard let record = record(identifier: identifier) else {
            throw RecoveryKeyringError.keyNotFound
        }
        guard record.role == .retained else {
            throw RecoveryKeyringError.cannotRemoveActive
        }
        records.removeAll { $0.identifier == identifier }
    }

    private mutating func demoteActive() {
        for index in records.indices where records[index].role == .active {
            records[index].role = .retained
        }
    }

    private mutating func sortRecords() {
        records.sort { lhs, rhs in
            if lhs.role != rhs.role { return lhs.role == .active }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func makeRecord(
        _ key: String,
        at date: Date,
        imported: Bool,
        role: RecoveryKeyRole
    ) throws -> RecoveryKeyRecord {
        let canonical = try CloudRecoveryKey.canonicalize(key)
        return RecoveryKeyRecord(
            identifier: try CloudRecoveryKey.identifier(canonical),
            canonicalKey: canonical,
            createdAt: date,
            importedAt: imported ? date : nil,
            role: role
        )
    }
}
