import SwiftUI
import VaultCore

struct ImportView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var overwrite = false
    @State private var envGlobs = "CF_* STRIPE_* *_TOKEN *_API_KEY"
    @State private var opItemRef = ""
    @State private var opCLIStatus: String?

    var body: some View {
        Form {
            Section {
                Toggle("Overwrite existing", isOn: $overwrite)
            } header: {
                Text("Options")
            } footer: {
                Text("When off, secrets that already exist in your vault are skipped.")
            }

            Section {
                LabeledContent(".env file") {
                    Button("Choose…") { pickDotenv() }
                }
                Text("Comments and `export` prefixes handled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Files")
            }

            Section {
                TextField("Globs", text: $envGlobs, prompt: Text("CF_* STRIPE_*"))
                    .font(.system(.body, design: .monospaced))
                Button("Import from environment") {
                    let globs = envGlobs.split(separator: " ").map(String.init)
                    env.importEnv(globs: globs, overwrite: overwrite)
                }
            } header: {
                Text("Shell environment")
            } footer: {
                Text("Pulls secrets from your current shell env matching any glob.")
            }

            Section {
                Button {
                    env.importClipboard(overwrite: overwrite)
                } label: {
                    Label("Import from clipboard", systemImage: "doc.on.clipboard")
                }
            } header: {
                Text("Clipboard")
            } footer: {
                Text("Copy KEY=VALUE lines to your clipboard first, then click.")
            }

            Section {
                HStack {
                    TextField("Item reference", text: $opItemRef, prompt: Text("Cloudflare API"))
                    Button("Import") {
                        env.importOnePassword(itemRef: opItemRef, overwrite: overwrite)
                    }
                    .disabled(opItemRef.isEmpty)
                }
                Button {
                    Task { opCLIStatus = await probeOpCLI() }
                } label: {
                    Label("Check op CLI", systemImage: "checkmark.circle")
                }
                if let s = opCLIStatus {
                    Text(s).font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("1Password")
            } footer: {
                Text("Requires the 1Password CLI signed in. Install: `brew install --cask 1password-cli`. Item reference is the name shown in 1Password (e.g. \"Cloudflare API\").")
            }

            Section {
                LabeledContent("System Keychain") {
                    Text("`vibevault import --from keychain`")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Other CLI sources")
            } footer: {
                Text("These sources need terminal access; CLI only for now.")
            }

            if let status = env.importStatus {
                Section {
                    Text(status).font(.callout)
                } header: {
                    Text("Last result")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Import Secrets")
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
