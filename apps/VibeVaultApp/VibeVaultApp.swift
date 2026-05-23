import SwiftUI
import VaultCore

@main
struct VibeVaultApp: App {
    @StateObject private var env = AppEnvironment.makeLive()

    var body: some Scene {
        WindowGroup("Vibe Vault", id: "main") {
            MainWindow()
                .environmentObject(env)
                .frame(minWidth: 880, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentMinSize)
        .commands { VibeVaultCommands() }

        MenuBarExtra("Vibe Vault", systemImage: "key.viewfinder") {
            MenuBarScene()
                .environmentObject(env)
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
