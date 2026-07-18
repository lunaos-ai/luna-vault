import SwiftUI
import VaultCore

/// Shows Cursor MCP health: vibe-vault present, shadow servers flagged.
struct ShadowMCPPanel: View {
    @State private var report: ShadowMCPReport = ShadowMCPScanner.scan(client: .cursor)

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cursor MCP health").font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Tokens.Text.secondary)
                }
                Spacer()
                Button { report = ShadowMCPScanner.scan(client: .cursor) } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Rescan ~/.cursor/mcp.json")
            }
            if !report.configExists {
                Label("No ~/.cursor/mcp.json yet — Install Cursor MCP above", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(Tokens.Status.warning)
            } else {
                statusRow(
                    ok: report.vibeVaultInstalled,
                    label: report.vibeVaultInstalled ? "vibe-vault connected" : "vibe-vault missing"
                )
                if report.shadowCount > 0 {
                    Text("\(report.shadowCount) other MCP server\(report.shadowCount == 1 ? "" : "s") (not managed by Vibe Vault)")
                        .font(.caption2)
                        .foregroundStyle(Tokens.Text.tertiary)
                    ForEach(report.servers.filter(\.isShadow).prefix(6)) { server in
                        HStack {
                            Text(server.name).font(.system(.caption, design: .monospaced))
                            Spacer()
                            Text("shadow")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Tokens.Status.warning)
                        }
                    }
                }
            }
        }
        .padding(Tokens.Space.lg)
        .cardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(subtitle)
    }

    private var subtitle: String {
        if !report.configExists { return "Install MCP to connect Cursor" }
        if report.vibeVaultInstalled && report.shadowCount == 0 {
            return "Only vibe-vault — clean"
        }
        if report.vibeVaultInstalled {
            return "Connected · \(report.shadowCount) shadow server\(report.shadowCount == 1 ? "" : "s")"
        }
        return "Config exists but vibe-vault is not installed"
    }

    private func statusRow(ok: Bool, label: String) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? Tokens.Status.success : Tokens.Status.warning)
            Text(label).font(.caption)
            Spacer()
        }
    }
}
