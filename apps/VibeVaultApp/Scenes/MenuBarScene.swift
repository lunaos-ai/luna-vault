import SwiftUI
import VaultCore

struct MenuBarScene: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.openWindow) private var openWindow
    @State private var query = ""

    private var filtered: [Secret] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return env.secrets }
        return env.secrets.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            header
            searchField

            secretList
                .glassPanel(radius: Tokens.Radius.md, elevation: .floating)

            actions
        }
        .padding(Tokens.Space.md)
        .frame(width: 300)
        .background(CompactLiquidBackdrop())
        .task { env.refresh() }
    }

    private var searchField: some View {
        HStack(spacing: Tokens.Space.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Tokens.Text.secondary).font(.caption)
            TextField("Search keys", text: $query)
                .textFieldStyle(.plain)
                .font(.system(.callout, design: .monospaced))
        }
        .padding(.horizontal, Tokens.Space.sm)
        .padding(.vertical, Tokens.Space.xs)
        .deepInset(radius: Tokens.Radius.sm)
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
            if filtered.isEmpty {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: query.isEmpty ? "tray" : "magnifyingglass")
                        .foregroundStyle(Tokens.Text.secondary)
                    Text(query.isEmpty ? "No secrets yet" : "No match")
                        .foregroundStyle(Tokens.Text.secondary)
                }
                .padding(.vertical, Tokens.Space.xs)
            } else {
                ForEach(filtered.prefix(6)) { secret in
                    secretRow(secret)
                }
                if filtered.count > 6 {
                    Text("+ \(filtered.count - 6) more…")
                        .foregroundStyle(Tokens.Text.secondary)
                        .font(.caption)
                }
            }
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func secretRow(_ secret: Secret) -> some View {
        Button { Task { await env.copyToClipboard(name: secret.name) } } label: {
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
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(Tokens.Text.tertiary)
                    .font(.caption)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Copy \(secret.name) (Touch ID)")
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
