import SwiftUI
import VaultCore

struct AIAgentsView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var statuses: [MCPClientKind: MCPClientStatus] = [:]
    @State private var lastError: String?
    @State private var binaryPath: String = MCPBinaryLocator.resolve()
    @State private var allowedSearch = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                serverCard
                ForEach(MCPClientKind.allCases) { client in
                    clientCard(client)
                }
                allowedSecretsCard
                if let err = lastError { errorCard(err) }
            }
            .padding(Tokens.Space.xxl)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(LiquidBackdrop())
        .navigationTitle("AI Agents")
        .task { refresh() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            }
        }
    }

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Vibe Vault MCP server").sectionLabel()
            LabeledContent("MCP binary") {
                Text(binaryPath)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            if !FileManager.default.isExecutableFile(atPath: binaryPath) {
                Label("Binary not found. Build with `swift build -c release` or run `scripts/bundle-app.sh`.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Tokens.Status.danger)
                    .font(.caption)
            }
            Text("AI agents launch this binary over stdio. It reads only the secrets you've marked \"Allow AI agents.\"")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .glassCard()
    }

    private func clientCard(_ client: MCPClientKind) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                Label(client.displayName, systemImage: client.systemImage)
                    .sectionLabel()
                Spacer()
                statusPill(for: client)
            }
            HStack(spacing: Tokens.Space.sm) {
                if statuses[client]?.installed == true {
                    Button("Reinstall") { install(client) }
                        .buttonStyle(.glass)
                        .disabled(!FileManager.default.isExecutableFile(atPath: binaryPath))
                    Button(role: .destructive) { uninstall(client) } label: { Text("Remove") }
                        .buttonStyle(.glass(tint: Tokens.Status.danger))
                } else {
                    Button("Install") { install(client) }
                        .buttonStyle(.glassProminent)
                        .disabled(!FileManager.default.isExecutableFile(atPath: binaryPath))
                }
                Spacer()
            }
            Text(client.docsHint).font(.caption).foregroundStyle(Tokens.Text.secondary)
        }
        .glassCard()
    }

    @ViewBuilder
    private func statusPill(for client: MCPClientKind) -> some View {
        if let status = statuses[client] {
            if status.installed {
                Text("Installed").glassChip(Tokens.Status.success)
            } else if status.configExists {
                Text("Not installed").font(.caption).foregroundStyle(Tokens.Text.secondary)
            } else if status.parentDirExists {
                Text("Client detected").font(.caption).foregroundStyle(Tokens.Text.secondary)
            } else {
                Text("Not detected").font(.caption).foregroundStyle(Tokens.Text.tertiary)
            }
        }
    }

    private var allowedSecretsCard: some View {
        let allowed = env.secrets.filter(\.mcpAllowed).sorted { $0.name < $1.name }
        let shown = allowedSearch.isEmpty
            ? allowed
            : allowed.filter { $0.name.localizedCaseInsensitiveContains(allowedSearch) }
        return VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                Text("MCP-allowed secrets (\(allowed.count))").sectionLabel()
                Spacer()
                if allowed.count > 4 { allowedSearchField }
            }
            if allowed.isEmpty {
                Text("No secrets are currently exposed to AI agents.")
                    .foregroundStyle(Tokens.Text.secondary)
            } else if shown.isEmpty {
                Text("No allowed secret matches \"\(allowedSearch)\".")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            } else {
                ForEach(shown) { secret in
                    HStack {
                        Text(secret.name).font(.system(.body, design: .monospaced))
                        Spacer()
                        Button(role: .destructive) {
                            Task { await disallow(secret.name) }
                        } label: {
                            Label("Revoke", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.glass(tint: Tokens.Status.danger))
                        .accessibilityLabel("Revoke AI access to \(secret.name)")
                    }
                }
            }
            Text("Toggle per secret from its detail view. Secrets without this flag are invisible to AI agents.")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .glassCard()
    }

    private var allowedSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.Text.tertiary)
            TextField("Filter", text: $allowedSearch)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(width: 120)
        }
        .padding(.horizontal, Tokens.Space.sm)
        .padding(.vertical, 4)
        .background(Tokens.Surface.elevated.opacity(0.6), in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .strokeBorder(Tokens.Glass.edge, lineWidth: Tokens.Stroke.hairline)
        )
    }

    private func errorCard(_ err: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Last error").sectionLabel()
            Text(err).foregroundStyle(Tokens.Status.danger)
        }
        .glassCard()
    }

    private func refresh() {
        var out: [MCPClientKind: MCPClientStatus] = [:]
        for kind in MCPClientKind.allCases {
            out[kind] = MCPClientInstaller.status(of: kind)
        }
        statuses = out
        binaryPath = MCPBinaryLocator.resolve()
    }

    private func install(_ client: MCPClientKind) {
        do {
            try MCPClientInstaller.install(kind: client, binaryPath: binaryPath)
            lastError = nil
            refresh()
        } catch { lastError = "\(error)" }
    }

    private func uninstall(_ client: MCPClientKind) {
        do {
            try MCPClientInstaller.uninstall(kind: client)
            lastError = nil
            refresh()
        } catch { lastError = "\(error)" }
    }

    private func disallow(_ name: String) async {
        do {
            try await env.service.setMCPAllowed(name: name, allowed: false)
            env.refresh()
        } catch { lastError = "\(error)" }
    }
}
