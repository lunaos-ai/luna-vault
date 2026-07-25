import Foundation

public struct CloudSyncComparison: Equatable, Sendable {
    public let newNames: [String]
    public let backupNewerNames: [String]
    public let localNewerNames: [String]
    public let sameTimestampNames: [String]

    public init(
        newNames: [String],
        backupNewerNames: [String],
        localNewerNames: [String],
        sameTimestampNames: [String]
    ) {
        self.newNames = newNames
        self.backupNewerNames = backupNewerNames
        self.localNewerNames = localNewerNames
        self.sameTimestampNames = sameTimestampNames
    }

    public var existingCount: Int {
        backupNewerNames.count + localNewerNames.count + sameTimestampNames.count
    }
}

public enum CloudSyncInspector {
    public static func compare(
        snapshot: CloudSyncSnapshot,
        localSecrets: [Secret],
        timestampTolerance: TimeInterval = 1
    ) -> CloudSyncComparison {
        let localByName = Dictionary(uniqueKeysWithValues: localSecrets.map { ($0.name, $0) })
        var newNames: [String] = []
        var backupNewerNames: [String] = []
        var localNewerNames: [String] = []
        var sameTimestampNames: [String] = []

        for item in snapshot.secrets {
            guard let local = localByName[item.name] else {
                newNames.append(item.name)
                continue
            }
            let difference = item.updatedAt.timeIntervalSince(local.updatedAt)
            if difference > timestampTolerance {
                backupNewerNames.append(item.name)
            } else if difference < -timestampTolerance {
                localNewerNames.append(item.name)
            } else {
                sameTimestampNames.append(item.name)
            }
        }

        return CloudSyncComparison(
            newNames: newNames.sorted(),
            backupNewerNames: backupNewerNames.sorted(),
            localNewerNames: localNewerNames.sorted(),
            sameTimestampNames: sameTimestampNames.sorted()
        )
    }
}
