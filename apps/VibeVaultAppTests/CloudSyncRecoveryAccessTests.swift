import XCTest
@testable import VibeVaultApp
import VaultCore

final class CloudSyncRecoveryAccessTests: XCTestCase {
    func test_disabled_preview_explains_missing_bundle_and_missing_key() {
        XCTAssertEqual(
            CloudSyncRecoveryAccess.previewICloudHelp(
                canPreview: false,
                bundleExists: false,
                canEnterKey: false,
                hasInstalledKeys: false
            ),
            "No iCloud bundle is present to preview."
        )
        XCTAssertEqual(
            CloudSyncRecoveryAccess.previewICloudHelp(
                canPreview: false,
                bundleExists: true,
                canEnterKey: false,
                hasInstalledKeys: false
            ),
            "Enter a valid VV-RK1 recovery key, or install a recovery key first."
        )
        XCTAssertEqual(
            CloudSyncRecoveryAccess.previewICloudHelp(
                canPreview: true,
                bundleExists: true,
                canEnterKey: true,
                hasInstalledKeys: true
            ),
            "Preview the iCloud bundle without importing secrets or changing keys."
        )
    }

    func test_disabled_import_and_save_actions_have_help_text() {
        XCTAssertEqual(
            CloudSyncRecoveryAccess.importHelp(canImport: false, hasPreview: false),
            "Preview a backup successfully before importing."
        )
        XCTAssertEqual(
            CloudSyncRecoveryAccess.keepForRestoresHelp(canUseKey: false),
            "Enter a valid VV-RK1 recovery key first."
        )
        XCTAssertEqual(
            CloudSyncRecoveryAccess.makeActiveHelp(canUseKey: true),
            "Use this key for new backups. The current active key stays available for restores."
        )
    }

    func test_legacy_match_copy_does_not_include_raw_key_material() {
        let label = CloudSyncRecoveryAccess.matchLabel(.legacyUnknown)
        XCTAssertEqual(label, CloudSyncRecoveryCopy.legacyIdentityUnavailable)
        XCTAssertFalse(label.contains("VV-RK1"))
    }
}
