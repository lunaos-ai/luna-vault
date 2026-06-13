import XCTest
@testable import VibeVaultApp

@MainActor
final class CloudGatingTests: XCTestCase {
    func test_disabledByDefault_blocksLoginWithoutNetwork() async {
        let auth = CloudAuthService.shared
        auth.setCloudEnabled(false)
        let ok = await auth.login(email: "a@b.co", password: "x")
        XCTAssertFalse(ok)
        XCTAssertEqual(auth.cloudEnabled, false)
        XCTAssertTrue(auth.lastError?.contains("off") ?? false)
    }

    func test_requireCloudEnabled_reflectsToggle() {
        let auth = CloudAuthService.shared
        auth.setCloudEnabled(false)
        XCTAssertFalse(auth.requireCloudEnabled())
        auth.setCloudEnabled(true)
        XCTAssertTrue(auth.requireCloudEnabled())
        auth.setCloudEnabled(false)  // restore safe default
    }
}
