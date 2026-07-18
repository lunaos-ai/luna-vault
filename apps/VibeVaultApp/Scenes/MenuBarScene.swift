import SwiftUI
import VaultCore

/// Search → Touch ID copy from the menu bar without opening the main window.
struct MenuBarScene: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.openWindow) private var openWindow
    @State private var query = ""
    @State private var copying: String?
    @FocusState private var searchFocused: Bool

    private var filtered: [Secret] {
        let base = env.secrets
        guard !query.isEmpty else { return Array(base.prefix(8)) }
        return base.filter { $0.name.localizedCaseInsensitiveContains(query) }.prefix(12).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            header
            TextField("Search secrets", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .focused($searchFocused)
            Divider()
            secretList
            Divider()
            footerButtons
        }
        .padding(Tokens.Space.md)
        .frame(width: 320)
        .task {
            env.refresh()
            searchFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "key.viewfinder")
                .foregroundStyle(Tokens.Palette.accent)
                .font(.title3)
            VStack(alignment: .leading, spacing: 0) {
                Text("Vibe Vault").font(.headline)
                Text("\(env.secrets.count) secret\(env.secrets.count == 1 ? "" : "s") · click to copy")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var secretList: some View {
        if env.secrets.isEmpty {
            Label("No secrets yet", systemImage: "tray")
                .foregroundStyle(Tokens.Text.secondary)
                .padding(.vertical, Tokens.Space.xs)
        } else if filtered.isEmpty {
            Text("No match for “\(query)”")
                .font(.caption)
                .foregroundStyle(Tokens.Text.tertiary)
                .padding(.vertical, Tokens.Space.xs)
        } else {
            ForEach(filtered) { secret in
                Button { Task { await copy(secret.name) } } label: {
                    HStack {
                        Text(secret.name)
                            .font(.system(.callout, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(Tokens.Text.primary)
                        Spacer()
                        if copying == secret.name {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(Tokens.Text.tertiary)
                        }
                    }
                }
                .buttonStyle(.borderless)
                .help("Copy \(secret.name) (Touch ID)")
                .accessibilityLabel("Copy \(secret.name)")
            }
            if query.isEmpty, env.secrets.count > 8 {
                Text("+ \(env.secrets.count - 8) more. Type to search")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
            }
        }
    }

    private var footerButtons: some View {
        HStack {
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open window", systemImage: "macwindow")
            }
            .buttonStyle(.borderless)
            Spacer()
            Button { NSApp.terminate(nil) } label: {
                Text("Quit").foregroundStyle(Tokens.Text.secondary)
            }
            .buttonStyle(.borderless)
        }
    }

    private func copy(_ name: String) async {
        copying = name
        defer { copying = nil }
        await env.copySecret(name: name)
    }
}

extension Secret: Identifiable {
    public var id: String { name }
}
