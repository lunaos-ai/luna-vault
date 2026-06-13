import SwiftUI
import VaultCore

struct MenuBarScene: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            header

            secretList
                .glassPanel(radius: Tokens.Radius.md, elevation: .floating)

            actions
        }
        .padding(Tokens.Space.md)
        .frame(width: 300)
        .background(CompactLiquidBackdrop())
        .task { env.refresh() }
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "key.viewfinder")
                .foregroundStyle(Tokens.Palette.accent)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("Vibe Vault").font(.headline)
                Text("\(env.secrets.count) secret\(env.secrets.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            Spacer()
        }
    }

    private var secretList: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            if env.secrets.isEmpty {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: "tray").foregroundStyle(Tokens.Text.secondary)
                    Text("No secrets yet")
                        .foregroundStyle(Tokens.Text.secondary)
                }
                .padding(.vertical, Tokens.Space.xs)
            } else {
                ForEach(env.secrets.prefix(5)) { secret in
                    secretRow(secret)
                }
                if env.secrets.count > 5 {
                    Text("+ \(env.secrets.count - 5) more…")
                        .foregroundStyle(Tokens.Text.secondary)
                        .font(.caption)
                }
            }
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func secretRow(_ secret: Secret) -> some View {
        HStack {
            Text(secret.name)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            if secret.isExpired || secret.isRotationDue {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Tokens.Status.danger)
                    .font(.caption)
                    .accessibilityLabel("Needs attention")
            }
            Text(secret.maskedValue)
                .foregroundStyle(Tokens.Text.secondary)
                .font(.system(.caption, design: .monospaced))
        }
    }

    private var actions: some View {
        VStack(spacing: Tokens.Space.sm) {
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Vibe Vault…", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .accessibilityLabel("Open Vibe Vault")

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Quit")
        }
    }
}

extension Secret: Identifiable {
    public var id: String { name }
}
