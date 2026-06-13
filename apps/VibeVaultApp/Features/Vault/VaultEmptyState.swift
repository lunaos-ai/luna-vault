import SwiftUI
import VaultCore

struct VaultEmptyState: View {
    @EnvironmentObject var nav: Navigator
    let onAdd: () -> Void
    var body: some View {
        VStack(spacing: Tokens.Space.xl) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.accent.opacity(0.05))
                    .frame(width: 96, height: 96)
                Image(systemName: "key.viewfinder")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
            VStack(spacing: Tokens.Space.xs) {
                Text("Nothing selected")
                    .font(.title2.weight(.semibold))
                    .tracking(-0.3)
                Text("Pick a secret from the list, search, or add a new one.")
                    .font(.body)
                    .foregroundStyle(Tokens.Text.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            HStack(spacing: Tokens.Space.md) {
                Button { nav.paletteOpen = true } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .buttonStyle(.glass)
                .controlSize(.large)

                Button(action: onAdd) {
                    Label("New Secret", systemImage: "plus")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Tokens.Space.xxl)
        .glassCard(radius: Tokens.Radius.lg, padding: Tokens.Space.xxxl, elevation: .lifted)
        .padding(Tokens.Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LiquidBackdrop())
    }
}
