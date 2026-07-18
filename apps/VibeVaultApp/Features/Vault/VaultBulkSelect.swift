import SwiftUI

/// Bottom chrome while multi-selecting secrets for bulk MCP allow/revoke.
struct VaultSelectBar: View {
    let selectedCount: Int
    let onAllow: () -> Void
    let onRevoke: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            Text(countLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Tokens.Text.primary)
                .accessibilityLabel(countLabel)
            Spacer(minLength: Tokens.Space.sm)
            Button("Allow AI", action: onAllow)
                .disabled(selectedCount == 0)
                .help("Let AI agents read the selected secrets via MCP")
            Button("Revoke AI", action: onRevoke)
                .disabled(selectedCount == 0)
                .help("Block AI agents from reading the selected secrets")
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.sm)
        .background(Tokens.Surface.elevated.opacity(0.9))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Tokens.Surface.separator.opacity(0.6))
                .frame(height: Tokens.Stroke.hairline)
        }
    }

    private var countLabel: String {
        selectedCount == 0
            ? "Select secrets"
            : "\(selectedCount) selected"
    }
}

/// Detail pane shown in select mode instead of a single secret.
struct VaultBulkSelectDetail: View {
    let selectedCount: Int
    let onAllow: () -> Void
    let onRevoke: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Space.xl) {
            Image(systemName: "checklist")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Tokens.Palette.accent.opacity(0.7))
            VStack(spacing: Tokens.Space.xs) {
                Text(headline)
                    .font(.title2.weight(.semibold))
                    .tracking(-0.3)
                Text("Toggle Allowed to AI for every selected secret at once.")
                    .font(.body)
                    .foregroundStyle(Tokens.Text.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            if selectedCount > 0 {
                HStack(spacing: Tokens.Space.sm) {
                    Button(action: onAllow) {
                        Label("Allow AI", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Tokens.Palette.accent)
                    Button(action: onRevoke) {
                        Label("Revoke AI", systemImage: "hand.raised")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PremiumBackdrop())
    }

    private var headline: String {
        selectedCount == 0
            ? "Select secrets"
            : "\(selectedCount) secret\(selectedCount == 1 ? "" : "s") selected"
    }
}
