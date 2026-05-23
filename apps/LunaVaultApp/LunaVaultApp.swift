import SwiftUI
import VaultCore

@main
struct LunaVaultApp: App {
    @StateObject private var env = AppEnvironment.makeLive()

    var body: some Scene {
        WindowGroup("luna-vault", id: "main") {
            MainWindow()
                .environmentObject(env)
                .frame(minWidth: 760, minHeight: 480)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .commands { LunaVaultCommands() }

        MenuBarExtra("luna-vault", systemImage: "key.viewfinder") {
            MenuBarScene()
                .environmentObject(env)
        }
        .menuBarExtraStyle(.window)
    }
}

struct LunaVaultCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About luna-vault") {}
        }
        CommandGroup(after: .newItem) {
            Button("New Secret…") {}.keyboardShortcut("n")
        }
    }
}
