import Foundation

public enum RecoveryKeyMatchStatus: Equatable, Sendable {
    case unprotected
    case matchedActive
    case matchedRetained
    case notInstalled
    case legacyUnknown
}

extension RecoveryKeyring {
    public func matchStatus(for info: CloudSyncBundleInfo) -> RecoveryKeyMatchStatus {
        guard info.hasRecoveryProtection else { return .unprotected }
        guard let identifier = info.recoveryKeyID else { return .legacyUnknown }
        guard let record = record(identifier: identifier) else { return .notInstalled }
        return record.role == .active ? .matchedActive : .matchedRetained
    }
}

public struct RecoveryKeyDependents: Equatable, Sendable {
    public let matchingCount: Int
    public let legacyUnattributedCount: Int
    public let scannedCount: Int

    public init(matchingCount: Int, legacyUnattributedCount: Int, scannedCount: Int) {
        self.matchingCount = matchingCount
        self.legacyUnattributedCount = legacyUnattributedCount
        self.scannedCount = scannedCount
    }
}

public enum RecoveryKeyBundleScanner {
    public static func scan(identifier: String, urls: [URL]) -> RecoveryKeyDependents {
        var matching = 0
        var legacy = 0
        var scanned = 0
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let info = try? CloudSync.inspect(data) else { continue }
            scanned += 1
            guard info.hasRecoveryProtection else { continue }
            if let stored = info.recoveryKeyID {
                if stored == identifier { matching += 1 }
            } else {
                legacy += 1
            }
        }
        return RecoveryKeyDependents(
            matchingCount: matching,
            legacyUnattributedCount: legacy,
            scannedCount: scanned
        )
    }
}
