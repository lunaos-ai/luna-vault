import SwiftUI
import XCTest
@testable import VibeVaultApp
@testable import VaultCore

/// Smoke coverage for the leaf feature views: render each with a fully stubbed
/// environment and assert `body` evaluates without crashing.
@MainActor
final class ViewSmokeTests: XCTestCase {
    func testVaultListRenders() {
        Smoke.render(VaultListView().environmentObject(Smoke.env()).environmentObject(Smoke.nav()))
    }

    func testVaultListEmptyRenders() {
        Smoke.render(VaultListView().environmentObject(Smoke.env(secrets: [])).environmentObject(Smoke.nav()))
    }

    func testSecretDetailRenders() {
        Smoke.render(SecretDetailView(secret: Smoke.sampleSecrets[0]).environmentObject(Smoke.env()))
    }

    func testSecretRowRenders() {
        Smoke.render(SecretRow(secret: Smoke.sampleSecrets[1]))
    }

    func testSecretBadgeStripRenders() {
        for s in Smoke.sampleSecrets {
            Smoke.render(SecretBadgeStrip(secret: s))
        }
    }

    func testAddSecretSheetRenders() {
        Smoke.render(AddSecretSheet().environmentObject(Smoke.env()))
    }

    func testRotateSheetRenders() {
        Smoke.render(RotateSheetView(secret: Smoke.sampleSecrets[0], isPresented: .constant(true))
            .environmentObject(Smoke.env()))
    }

    func testImportViewRenders() {
        Smoke.render(ImportView().environmentObject(Smoke.env()))
    }

    func testAIAgentsRenders() {
        Smoke.render(AIAgentsView().environmentObject(Smoke.env()))
    }

    func testAuditLogRenders() {
        Smoke.render(AuditLogView().environmentObject(Smoke.env()))
    }

    func testProviderSyncRenders() {
        Smoke.render(ProviderSyncView().environmentObject(Smoke.env()))
    }

    func testProviderSecretPickerRenders() {
        Smoke.render(ProviderSecretPicker(
            secrets: Smoke.sampleSecrets,
            secretSearch: .constant(""),
            selectedSecrets: .constant(["API_KEY"])
        ))
    }

    func testProjectScannerRenders() {
        Smoke.render(ProjectScannerView().environmentObject(Smoke.env(scan: Smoke.sampleScan)))
    }

    func testScanResultCardRenders() {
        Smoke.render(ProjectScanResultCard(result: Smoke.sampleScan, filter: .all, projectURL: nil)
            .environmentObject(Smoke.env()))
    }

    func testScanStatusBannerRenders() {
        Smoke.render(ScanStatusBanner(text: "Scanned 12 files, 1 missing"))
    }

    func testCommandPaletteRenders() {
        Smoke.render(CommandPaletteView().environmentObject(Smoke.env()).environmentObject(Smoke.nav()))
    }
}
