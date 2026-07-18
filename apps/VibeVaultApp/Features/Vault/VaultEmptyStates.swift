import SwiftUI

struct VaultSelectHint: View {
    let secretCount: Int
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Space.xl) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Tokens.Palette.accent.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                Image(systemName: "key.viewfinder")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Tokens.Palette.accent.opacity(0.6))
            }
            VStack(spacing: Tokens.Space.xs) {
                Text("Select a secret")
                    .font(.title2.weight(.semibold))
                    .tracking(-0.3)
                Text("\(secretCount) in vault · pick one to reveal or copy")
                    .font(.body)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            Button(action: onAdd) {
                Label("New Secret", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Tokens.Palette.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PremiumBackdrop())
    }
}

struct VaultEmptyState: View {
    var isFirstRun: Bool
    let onAdd: () -> Void
    var onScan: (() -> Void)? = nil
    var onImport: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Tokens.Space.xl) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Tokens.Palette.accent.opacity(0.06), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                Image(systemName: isFirstRun ? "tray" : "key.viewfinder")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
            VStack(spacing: Tokens.Space.xs) {
                Text(isFirstRun ? "No secrets yet" : "Nothing selected")
                    .font(.title2.weight(.semibold))
                    .tracking(-0.3)
                Text(isFirstRun
                     ? "Scan a project to import from .env, or add secrets manually."
                     : "Pick a secret from the list, or add a new one.")
                    .font(.body)
                    .foregroundStyle(Tokens.Text.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            if isFirstRun {
                HStack(spacing: Tokens.Space.sm) {
                    if let onScan {
                        Button(action: onScan) {
                            Label("Scan project", systemImage: "folder.badge.questionmark")
                        }
                        .buttonStyle(.bordered)
                    }
                    if let onImport {
                        Button(action: onImport) {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            Button(action: onAdd) {
                Label("New Secret", systemImage: "plus")
                    .font(.body.weight(.medium))
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PremiumBackdrop())
    }
}
