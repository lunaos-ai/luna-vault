import XCTest
@testable import VaultCore

final class CloudBackupArchiveTests: XCTestCase {
    func test_backupURL_uses_stable_timestamp_and_safe_identifier() {
        let directory = URL(fileURLWithPath: "/tmp/vibevault-backups", isDirectory: true)
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        let url = CloudBackupArchive.backupURL(
            in: directory,
            at: date,
            identifier: "Mac A / 123"
        )

        XCTAssertEqual(url.lastPathComponent, "vault-20270115-080000-maca123.vvsync")
    }

    func test_write_lists_newest_first_and_prunes_old_backups() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        for index in 0..<4 {
            _ = try CloudBackupArchive.write(
                Data("backup-\(index)".utf8),
                to: directory,
                at: Date(timeIntervalSince1970: TimeInterval(1_800_000_000 + index)),
                identifier: "\(index)",
                retentionCount: 3
            )
        }

        let backups = try CloudBackupArchive.list(in: directory)
        XCTAssertEqual(backups.count, 3)
        XCTAssertEqual(
            backups.map(\.url.lastPathComponent),
            [
                "vault-20270115-080003-3.vvsync",
                "vault-20270115-080002-2.vvsync",
                "vault-20270115-080001-1.vvsync"
            ]
        )
    }

    func test_prune_ignores_unmanaged_vvsync_files() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let manual = directory.appendingPathComponent("manual.vvsync")
        try Data("manual".utf8).write(to: manual)

        _ = try CloudBackupArchive.write(
            Data("managed".utf8),
            to: directory,
            identifier: "managed",
            retentionCount: 1
        )
        _ = try CloudBackupArchive.prune(in: directory, keeping: 1)

        XCTAssertTrue(FileManager.default.fileExists(atPath: manual.path))
    }

    func test_schedule_is_due_for_first_run_and_after_interval() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertTrue(CloudBackupSchedule.isDue(lastBackupAt: nil, intervalHours: 24, now: now))
        XCTAssertFalse(
            CloudBackupSchedule.isDue(
                lastBackupAt: now.addingTimeInterval(-23 * 60 * 60),
                intervalHours: 24,
                now: now
            )
        )
        XCTAssertTrue(
            CloudBackupSchedule.isDue(
                lastBackupAt: now.addingTimeInterval(-24 * 60 * 60),
                intervalHours: 24,
                now: now
            )
        )
    }
}
