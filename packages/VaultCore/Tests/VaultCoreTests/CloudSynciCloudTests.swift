import Foundation
import XCTest
@testable import VaultCore

final class CloudSynciCloudTests: XCTestCase {
    func test_default_icloud_path_is_vibevault_sync_bundle() {
        let path = CloudSync.defaultICloudURL().path
        XCTAssertTrue(path.contains("Mobile Documents/com~apple~CloudDocs/Documents"))
        XCTAssertTrue(path.hasSuffix("VibeVault/Sync/vault.vvsync"))
    }

    func test_icloud_availability_requires_a_writable_directory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertFalse(CloudSync.isICloudDriveAvailable(at: root))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        XCTAssertTrue(CloudSync.isICloudDriveAvailable(at: root))
    }

    func test_icloud_availability_rejects_a_file() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: root)

        XCTAssertFalse(CloudSync.isICloudDriveAvailable(at: root))
    }
}
