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
                .onAppear { CommandBridge.shared.env = env }
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
    @ObservedObject private var bridge = CommandBridge.shared

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Vibe Vault") {}
        }
        CommandGroup(after: .newItem) {
            Button("New Secret…") {
                bridge.env?.openAddSecret = true
            }
            .keyboardShortcut("n")
            Button("Find in Vault…") {
                bridge.env?.focusVaultSearch = true
            }
            .keyboardShortcut("f")
            Button("Copy Secret") {
                bridge.env?.copySelectedSecret = true
            }
            .keyboardShortcut("c")
        }
    }
}

@MainActor
final class CommandBridge: ObservableObject {
    static let shared = CommandBridge()
    weak var env: AppEnvironment?
}
