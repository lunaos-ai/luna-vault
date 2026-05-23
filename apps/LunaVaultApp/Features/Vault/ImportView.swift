import SwiftUI
import VaultCore

struct ImportView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var overwrite = false
    @State private var envGlobs = "CF_* STRIPE_* *_TOKEN *_API_KEY"

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            Text("Import secrets").font(.title2.bold())
            Text("Pull existing secrets from where you keep them today.")
                .foregroundStyle(Tokens.Color.textSecondary)

            Toggle("Overwrite existing secrets if name matches", isOn: $overwrite)

            sourceCard(
                title: ".env file",
                icon: "doc.text",
                description: "Parse a `.env` or `.env.local` file. Comments and `export` prefixes handled."
            ) {
                Button("Choose .env file…") { pickDotenv() }
                    .buttonStyle(.borderedProminent)
                    .tint(Tokens.Color.primary)
            }

            sourceCard(
                title: "Shell environment",
                icon: "terminal",
                description: "Pull from your current shell env by glob pattern."
            ) {
                HStack {
                    TextField("Globs (space-separated)", text: $envGlobs)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button("Import") {
                        let globs = envGlobs.split(separator: " ").map(String.init)
                        env.importEnv(globs: globs, overwrite: overwrite)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Tokens.Color.primary)
                }
            }

            sourceCard(
                title: "Clipboard",
                icon: "doc.on.clipboard",
                description: "Paste dotenv-shaped lines (KEY=VALUE per line) into your clipboard, then click import."
            ) {
                Button("Import from clipboard") {
                    env.importClipboard(overwrite: overwrite)
                }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.Color.primary)
            }

            sourceCard(
                title: "1Password & system Keychain",
                icon: "lock.fill",
                description: "CLI only for now: `lunavault import --from op --item <name>` or `--from keychain`."
            ) {
                EmptyView()
            }

            if let status = env.importStatus {
                Text(status)
                    .padding(Tokens.Space.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Tokens.Color.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm))
            }

            Spacer()
        }
        .padding(Tokens.Space.xl)
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

    private func sourceCard<Content: View>(
        title: String, icon: String, description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                Image(systemName: icon).foregroundStyle(Tokens.Color.primary)
                Text(title).font(.headline)
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(Tokens.Color.textSecondary)
            content()
        }
        .cardSurface()
    }
}
