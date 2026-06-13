import SwiftUI
import XCTest
@testable import VibeVaultApp
@testable import VaultCore

@MainActor
final class NewViewSmokeTests: XCTestCase {
    private var env: AppEnvironment { Smoke.env() }
    private var secret: Secret { Smoke.sampleSecrets[0] }

    func test_menuBarScene_renders() {
        Smoke.render(MenuBarScene().environmentObject(env))
    }

    func test_historySheet_renders() {
        Smoke.render(HistorySheetView(secret: secret, isPresented: .constant(true))
            .environmentObject(env))
    }

    func test_envExport_renders() {
        Smoke.render(EnvExportView(names: [secret.name], isPresented: .constant(true))
            .environmentObject(env))
    }

    func test_secretActionsBar_renders() {
        Smoke.render(SecretActionsBar(
            secret: secret,
            showRotate: .constant(false),
            showHistory: .constant(false),
            showExport: .constant(false),
            deleteConfirm: .constant(false)
        ).environmentObject(env))
    }
}
