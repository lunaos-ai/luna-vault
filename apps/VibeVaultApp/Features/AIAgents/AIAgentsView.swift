import SwiftUI
import VaultCore

struct AIAgentsView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var statuses: [MCPClientID: MCPInstallStatus] = [:]
    @State private var lastError: String?
    @State private var testResult: String?
    @State private var testing = false
    @State private var binaryPath: String = MCPBinaryLocator.resolve()

    private var priorityClients: [MCPClientID] {
        [.cursor, .vscode, .devin, .claudeCode, .claudeDesktop]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                hero
                AISkillSection()
                ShadowMCPPanel()
                clientGrid
                CLICommandsReference()
                AIPluginSection(manifests: PluginManifestLoader.loadAll())
                allowedSection
                if let err = lastError { errorBanner(err) }
            }
            .padding(Tokens.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PremiumBackdrop())
        .navigationTitle("AI Agents")
        .task { refresh() }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { installAll() } label: { Label("Install all", systemImage: "square.and.arrow.down") }
                    .disabled(!binaryReady)
                Button { Task { await runTest() } } label: {
                    Label(testing ? "Testing…" : "Test MCP", systemImage: "antenna.radiowaves.left.and.right")
                }
                .disabled(!binaryReady || testing)
                Button { refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            }
        }
    }

    private var binaryReady: Bool { FileManager.default.isExecutableFile(atPath: binaryPath) }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Tokens.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Cursor, VS Code, Devin")
                        .font(.headline)
                    Text("MCP server exposes only secrets you mark AI-allowed. Every read is audited.")
                        .font(.caption)
                        .foregroundStyle(Tokens.Text.secondary)
                }
            }
            Text(binaryPath)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Tokens.Text.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let testResult {
                Text(testResult).font(.caption).foregroundStyle(Tokens.Text.secondary)
            }
        }
        .padding(Tokens.Space.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
    }

    private var clientGrid: some View {
        VStack(spacing: Tokens.Space.md) {
            ForEach(priorityClients, id: \.self) { client in
                AIAgentClientRow(
                    client: client,
                    status: statuses[client],
                    binaryReady: binaryReady,
                    onInstall: { install(client) },
                    onRemove: { uninstall(client) }
                )
            }
        }
    }

    private var allowedSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("MCP-allowed secrets (\(env.secrets.filter(\.mcpAllowed).count))")
                .font(.subheadline.weight(.semibold))
            let allowed = env.secrets.filter(\.mcpAllowed).sorted { $0.name < $1.name }
            if allowed.isEmpty {
                Text("No secrets exposed yet. Enable per secret in Vault detail, or during import.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            } else {
                ForEach(allowed) { secret in
                    HStack {
                        Text(secret.name).font(.system(.caption, design: .monospaced))
                        Spacer()
                        Button("Revoke") { Task { await revoke(secret.name) } }
                            .font(.caption)
                            .buttonStyle(.link)
                    }
                }
            }
        }
        .padding(Tokens.Space.lg)
        .cardSurface()
    }

    private func errorBanner(_ text: String) -> some View {
        ImportStatusBanner(message: "error: \(text)")
    }

    private func refresh() {
        var out: [MCPClientID: MCPInstallStatus] = [:]
        for kind in MCPClientID.allCases { out[kind] = MCPClientInstaller.status(of: kind) }
        statuses = out
        binaryPath = MCPBinaryLocator.resolve()
    }

    private func install(_ client: MCPClientID) {
        do {
            try MCPClientInstaller.install(client: client, binaryPath: binaryPath)
            lastError = nil
            refresh()
        } catch { lastError = "\(error)" }
    }

    private func uninstall(_ client: MCPClientID) {
        do {
            try MCPClientInstaller.uninstall(client: client)
            lastError = nil
            refresh()
        } catch { lastError = "\(error)" }
    }

    private func installAll() {
        for client in priorityClients { install(client) }
    }

    private func revoke(_ name: String) async {
        do {
            try await env.service.setMCPAllowed(name: name, allowed: false)
            env.refresh()
        } catch { lastError = "\(error)" }
    }

    @MainActor
    private func runTest() async {
        testing = true
        defer { testing = false }
        let r = await MCPConnectionTest.run(binaryPath: binaryPath)
        testResult = r.message
        if !r.ok { lastError = r.message }
    }
}
