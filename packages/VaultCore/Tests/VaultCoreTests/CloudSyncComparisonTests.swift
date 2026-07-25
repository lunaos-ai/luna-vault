import XCTest
@testable import VaultCore

final class CloudSyncComparisonTests: XCTestCase {
    func test_compare_classifies_new_and_existing_secrets_by_timestamp() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let local = [
            Secret(name: "BACKUP_NEWER", value: "local", updatedAt: now),
            Secret(name: "LOCAL_NEWER", value: "local", updatedAt: now),
            Secret(name: "SAME", value: "local", updatedAt: now)
        ]
        let snapshot = CloudSyncSnapshot(secrets: [
            CloudSyncSecret(name: "NEW", value: "new", updatedAt: now),
            CloudSyncSecret(name: "BACKUP_NEWER", value: "backup", updatedAt: now.addingTimeInterval(10)),
            CloudSyncSecret(name: "LOCAL_NEWER", value: "backup", updatedAt: now.addingTimeInterval(-10)),
            CloudSyncSecret(name: "SAME", value: "backup", updatedAt: now.addingTimeInterval(0.5))
        ])

        let comparison = CloudSyncInspector.compare(snapshot: snapshot, localSecrets: local)

        XCTAssertEqual(comparison.newNames, ["NEW"])
        XCTAssertEqual(comparison.backupNewerNames, ["BACKUP_NEWER"])
        XCTAssertEqual(comparison.localNewerNames, ["LOCAL_NEWER"])
        XCTAssertEqual(comparison.sameTimestampNames, ["SAME"])
        XCTAssertEqual(comparison.existingCount, 3)
    }
}
