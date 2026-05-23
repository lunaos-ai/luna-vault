import SwiftUI
import VaultCore

struct ImportView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var overwrite = false
    @State private var envGlobs = "CF_* STRIPE_* *_TOKEN *_API_KEY"

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
                LabeledContent("1Password") {
                    Text("`vibevault import --from op --item <name>`")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                LabeledContent("System Keychain") {
                    Text("`vibevault import --from keychain`")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("CLI sources")
            } footer: {
                Text("These sources need terminal access and are not yet wrapped in UI.")
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
}
