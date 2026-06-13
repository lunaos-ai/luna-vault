import SwiftUI
import VaultCore

@main
struct VibeVaultApp: App {
    @StateObject private var env = AppEnvironment.makeLive()
    @StateObject private var nav = Navigator()
    @StateObject private var cloudAuth = CloudAuthService.shared
    @StateObject private var cloudBackup = CloudBackupService.shared
    @StateObject private var iapManager = IAPManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup("Vibe Vault", id: "main") {
            MainWindow()
                .environmentObject(env)
                .environmentObject(nav)
                .environmentObject(cloudAuth)
                .environmentObject(cloudBackup)
                .environmentObject(iapManager)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .frame(minWidth: 880, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentMinSize)
        .commands { VibeVaultCommands() }

        MenuBarExtra("Vibe Vault", systemImage: "key.viewfinder") {
            MenuBarScene()
                .environmentObject(env)
                .environmentObject(cloudAuth)
        }
        .menuBarExtraStyle(.window)
    }
}

struct VibeVaultCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Vibe Vault") {}
        }
        CommandGroup(after: .newItem) {
            Button("New Secret…") {}.keyboardShortcut("n")
        }
    }
}
