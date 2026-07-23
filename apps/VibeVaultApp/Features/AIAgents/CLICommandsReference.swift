import AppKit
import SwiftUI

/// Compact CLI cheatsheet for AI Agents — SF Mono for commands (DESIGN Mono-For-Identifiers).
struct CLICommandsReference: View {
    private static let rows: [(cmd: String, blurb: String)] = [
        ("vibevault list", "List secrets in the vault"),
        ("vibevault scan", "Detect required env vars in a project"),
        ("vibevault agents prepare", "Install Codex, Claude, Gemini, Cursor policy"),
        ("vibevault cursor prepare", "Rules, skill, MCP, and .env guard"),
        ("vibevault mcp install --client cursor", "Wire vibe-vault into Cursor"),
        ("vibevault mcp test", "Smoke-test the MCP server"),
        ("vibevault license status", "Show Team license state"),
        ("vibevault guard install", "Block accidental .env commits"),
        ("vibevault run -- <cmd>", "Run a command with vault secrets injected"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CLI reference").font(.subheadline.weight(.semibold))
                Text("Common terminal commands. Full help: `vibevault --help`.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                ForEach(Self.rows, id: \.cmd) { row in
                    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.md) {
                        Text(row.cmd)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(minWidth: 240, alignment: .leading)
                        Text(row.blurb)
                            .font(.caption)
                            .foregroundStyle(Tokens.Text.secondary)
                        Spacer(minLength: 0)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(row.cmd, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy command")
                        .accessibilityLabel("Copy \(row.cmd)")
                    }
                }
            }
        }
        .padding(Tokens.Space.lg)
        .cardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("CLI reference")
    }
}
