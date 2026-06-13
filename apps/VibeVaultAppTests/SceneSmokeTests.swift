import SwiftUI
import XCTest
@testable import VibeVaultApp
@testable import VaultCore

/// Smoke coverage for top-level scenes and shared theme views.
@MainActor
final class SceneSmokeTests: XCTestCase {
    func testMainWindowRenders() {
        Smoke.render(MainWindow().environmentObject(Smoke.env()).environmentObject(Smoke.nav()))
    }

    func testMenuBarSceneRenders() {
        Smoke.render(MenuBarScene().environmentObject(Smoke.env()))
    }

    func testSettingsRenders() {
        Smoke.render(SettingsView().environmentObject(Smoke.env()))
    }

    func testOnboardingRenders() {
        Smoke.render(OnboardingScene(done: .constant(false)).environmentObject(Smoke.env()))
    }

    func testLiquidBackdropRenders() {
        Smoke.render(LiquidBackdrop())
    }

    func testEmptyStateRenders() {
        Smoke.render(VaultEmptyState(onAdd: {}))
    }
}
