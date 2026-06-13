import SwiftUI
import VaultCore

struct ImportView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var overwrite = false
    @State private var envGlobs = "CF_* STRIPE_* *_TOKEN *_API_KEY"
    @State private var opItemRef = ""
    @State private var opCLIStatus: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                optionsCard
                filesCard
                shellCard
                clipboardCard
                onePasswordCard
                cliSourcesCard
                if let status = env.importStatus {
                    resultCard(status)
                }
            }
            .padding(Tokens.Space.xxl)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(LiquidBackdrop())
        .navigationTitle("Import Secrets")
    }

    // MARK: - Cards

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Options").sectionLabel()
            Toggle("Overwrite existing", isOn: $overwrite)
                .toggleStyle(.switch)
            Text("When off, secrets that already exist in your vault are skipped.")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .glassCard()
    }

    private var filesCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Files").sectionLabel()
            LabeledContent(".env file") {
                Button("Choose…") { pickDotenv() }
                    .buttonStyle(.glass)
            }
            Text("Comments and `export` prefixes handled.")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .glassCard()
    }

    private var shellCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Shell environment").sectionLabel()
            TextField("Globs", text: $envGlobs, prompt: Text("CF_* STRIPE_*"))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Button("Import from environment") {
                let globs = envGlobs.split(separator: " ").map(String.init)
                env.importEnv(globs: globs, overwrite: overwrite)
            }
            .buttonStyle(.glassProminent)
            Text("Pulls secrets from your current shell env matching any glob.")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .glassCard()
    }

    private var clipboardCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Clipboard").sectionLabel()
            Button {
                env.importClipboard(overwrite: overwrite)
            } label: {
                Label("Import from clipboard", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.glass)
            Text("Copy KEY=VALUE lines to your clipboard first, then click.")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .glassCard()
    }

    private var onePasswordCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("1Password").sectionLabel()
            HStack {
                TextField("Item reference", text: $opItemRef, prompt: Text("Cloudflare API"))
                    .textFieldStyle(.roundedBorder)
                Button("Import") {
                    env.importOnePassword(itemRef: opItemRef, overwrite: overwrite)
                }
                .buttonStyle(.glassProminent)
                .disabled(opItemRef.isEmpty)
            }
            Button {
                Task { opCLIStatus = await probeOpCLI() }
            } label: {
                Label("Check op CLI", systemImage: "checkmark.circle")
            }
            .buttonStyle(.glass)
            if let s = opCLIStatus {
                Text(s).font(.caption).foregroundStyle(Tokens.Text.secondary)
            }
            Text("Requires the 1Password CLI signed in. Install: `brew install --cask 1password-cli`. Item reference is the name shown in 1Password (e.g. \"Cloudflare API\").")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .glassCard()
    }

    private var cliSourcesCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Other CLI sources").sectionLabel()
            LabeledContent("System Keychain") {
                Text("`vibevault import --from keychain`")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Tokens.Text.secondary)
            }
            Text("These sources need terminal access; CLI only for now.")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .glassCard()
    }

    private func resultCard(_ status: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Last result").sectionLabel()
            Text(status)
                .font(.callout)
                .glassChip(Tokens.Palette.accent)
        }
        .glassCard()
    }

    private func pickDotenv() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = []
        panel.treatsFilePackagesAsDirectories = true
        panel.showsHiddenFiles = true
        panel.begin { resp in
            if resp == .OK, let url = panel.url {
                env.importDotenv(at: url, overwrite: overwrite)
            }
        }
    }

    private func probeOpCLI() async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["op", "--version"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return "op CLI not found. brew install --cask 1password-cli" }
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            let v = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "op CLI \(v) detected. If import fails, sign in: `op signin`."
        }
        return "op CLI present but not signed in. Run `op signin` in your terminal."
    }
}
