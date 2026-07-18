import XCTest
@testable import VaultCore

final class GitLeakScannerTests: XCTestCase {
    func test_isSensitivePath_matchesEnvVariants() {
        XCTAssertTrue(GitLeakScanner.isSensitivePath(".env"))
        XCTAssertTrue(GitLeakScanner.isSensitivePath("apps/api/.env.local"))
        XCTAssertTrue(GitLeakScanner.isSensitivePath(".env.production"))
        XCTAssertFalse(GitLeakScanner.isSensitivePath(".env.example"))
        XCTAssertFalse(GitLeakScanner.isSensitivePath(".env.sample"))
        XCTAssertFalse(GitLeakScanner.isSensitivePath("README.md"))
    }

    func test_trackedLeaks_filtersWithInjectedRunner() {
        let root = URL(fileURLWithPath: "/tmp/proj")
        let runner: (URL, [String]) throws -> String = { _, args in
            if args == ["rev-parse", "--is-inside-work-tree"] { return "true\n" }
            if args.first == "ls-files" {
                return ".env\0README.md\0apps/.env.local\0.env.example\0"
            }
            return ""
        }
        let leaks = GitLeakScanner.trackedLeaks(projectURL: root, runner: runner)
        XCTAssertEqual(leaks, [".env", "apps/.env.local"])
    }

    func test_trackedLeaks_emptyWhenNotGit() {
        let root = URL(fileURLWithPath: "/tmp/proj")
        let runner: (URL, [String]) throws -> String = { _, _ in "false\n" }
        XCTAssertEqual(GitLeakScanner.trackedLeaks(projectURL: root, runner: runner), [])
    }

    func test_suggestGitignoreLines() {
        let lines = GitLeakScanner.suggestGitignoreLines(for: [".env"])
        XCTAssertTrue(lines.contains(".env"))
        XCTAssertTrue(lines.contains("!.env.example"))
        XCTAssertEqual(GitLeakScanner.suggestGitignoreLines(for: []), [])
    }

    func test_providerNameReconcile_sets() {
        let r = ProviderNameReconcile(
            remoteNames: ["A", "B"],
            localNames: ["B", "C"]
        )
        XCTAssertEqual(r.missingLocally, ["A"])
        XCTAssertEqual(r.extraLocally, ["C"])
        XCTAssertEqual(r.inSync, ["B"])
    }

    func test_preCommitGuard_hookContainsMarker() {
        XCTAssertTrue(PreCommitGuard.hookBody.contains(PreCommitGuard.marker))
        XCTAssertTrue(PreCommitGuard.hookBody.contains("vibevault scan"))
    }
}

final class ProviderCredentialStoreTests: XCTestCase {
    func test_vercelToken_roundTrip() {
        let prefs = InMemoryPrefs()
        XCTAssertNil(ProviderCredentialStore.vercelToken(prefs: prefs))
        ProviderCredentialStore.setVercelToken("vt_test", prefs: prefs)
        XCTAssertEqual(ProviderCredentialStore.vercelToken(prefs: prefs), "vt_test")
        ProviderCredentialStore.setVercelToken(nil, prefs: prefs)
        XCTAssertNil(ProviderCredentialStore.vercelToken(prefs: prefs))
    }

    func test_cloudflareToken_roundTrip() {
        let prefs = InMemoryPrefs()
        ProviderCredentialStore.setCloudflareToken("cf_tok", prefs: prefs)
        XCTAssertEqual(ProviderCredentialStore.cloudflareToken(prefs: prefs), "cf_tok")
    }
}
