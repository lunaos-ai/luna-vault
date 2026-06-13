import SwiftUI
import VaultCore

/// Shared navigation state so the command palette can drive the sidebar
/// selection and reveal a specific secret from anywhere in the app.
@MainActor
final class Navigator: ObservableObject {
    @Published var section: MainWindow.SidebarItem = .vault
    @Published var pendingSecret: Secret.ID?
    @Published var paletteOpen = false

    /// Switch the sidebar to a top-level destination and close the palette.
    func go(_ item: MainWindow.SidebarItem) {
        section = item
        paletteOpen = false
    }

    /// Jump to the vault and ask the list to select a specific secret.
    func reveal(secret id: Secret.ID) {
        pendingSecret = id
        section = .vault
        paletteOpen = false
    }

    func togglePalette() { paletteOpen.toggle() }
}
