import SwiftUI
import VaultCore

struct AIAgentsView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var statuses: [MCPClientKind: MCPClientStatus] = [:]
    @State private var lastError: String?
    @State private var binaryPath: String = MCPBinaryLocator.resolve()

    var body: some View {
        Form {
            Section {
                LabeledContent("MCP binary") {
                    Text(binaryPath)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                if !FileManager.default.isExecutableFile(atPath: binaryPath) {
                    Label("Binary not found. Build with `swift build -c release` or run `scripts/bundle-app.sh`.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            } header: {
                Text("Vibe Vault MCP server")
            } footer: {
                Text("AI agents launch this binary over stdio. It reads only the secrets you've marked \"Allow AI agents.\"")
            }

            ForEach(MCPClientKind.allCases) { client in
                clientSection(client)
            }

            Section {
                allowedSecrets
            } header: {
                Text("MCP-allowed secrets (\(env.secrets.filter(\.mcpAllowed).count))")
            } footer: {
                Text("Toggle per secret from its detail view. Secrets without this flag are invisible to AI agents.")
            }

            if let err = lastError {
                Section { Text(err).foregroundStyle(.red) } header: { Text("Last error") }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("AI Agents")
        .task { refresh() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            }
        }
    }

    private func clientSection(_ client: MCPClientKind) -> some View {
        Section {
            HStack {
                Label(client.displayName, systemImage: client.systemImage)
                Spacer()
                if let status = statuses[client] {
                    if status.installed {
                        Label("Installed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .labelStyle(.titleAndIcon)
                    } else if status.configExists {
                        Text("Not installed").foregroundStyle(.secondary)
                    } else if status.parentDirExists {
                        Text("Client detected").foregroundStyle(.secondary)
                    } else {
                        Text("Not detected").foregroundStyle(.tertiary)
                    }
                }
            }
            HStack {
                Button(statuses[client]?.installed == true ? "Reinstall" : "Install") {
                    install(client)
                }
                .disabled(!FileManager.default.isExecutableFile(atPath: binaryPath))
                if statuses[client]?.installed == true {
                    Button(role: .destructive) { uninstall(client) } label: { Text("Remove") }
                }
                Spacer()
            }
            Text(client.docsHint).font(.caption).foregroundStyle(.secondary)
        } header: {
            Text(client.displayName)
        }
    }

    private var allowedSecrets: some View {
        let allowed = env.secrets.filter(\.mcpAllowed).sorted { $0.name < $1.name }
        return Group {
            if allowed.isEmpty {
                Text("No secrets are currently exposed to AI agents.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(allowed) { secret in
                    HStack {
                        Text(secret.name).font(.system(.body, design: .monospaced))
                        Spacer()
                        Button(role: .destructive) {
                            Task { await disallow(secret.name) }
                        } label: {
                            Label("Revoke", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
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
