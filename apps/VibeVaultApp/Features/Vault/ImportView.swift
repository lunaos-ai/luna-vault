import SwiftUI
import VaultCore

struct ImportView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var overwrite = false
    @State private var envGlobs = "CF_* STRIPE_* *_TOKEN *_API_KEY"
    @State private var opItemRef = ""
    @State private var opCLIStatus: String?
    @State private var reviewSheet: ImportReviewPayload?

    struct ImportReviewPayload: Identifiable {
        let id = UUID()
        let subtitle: String
        let rows: [ImportRowState]
        let notes: String
    }

    var body: some View {
        VStack(spacing: 0) {
            if let status = env.importStatus {
                ImportStatusBanner(message: status)
                    .padding(.horizontal, Tokens.Space.xl)
                    .padding(.top, Tokens.Space.lg)
                    .padding(.bottom, Tokens.Space.sm)
            }
            importHero
            Form {
                Section {
                    Toggle("Overwrite existing", isOn: $overwrite)
                } header: {
                    Text("Options")
                } footer: {
                    Text("When off, secrets that already exist in your vault are skipped.")
                }

                Section {
                    ClipboardImportSection(overwrite: overwrite) { items in
                        reviewSheet = ImportReviewPayload(
                            subtitle: "Clipboard",
                            rows: ImportRowState.from(items),
                            notes: "imported from clipboard"
                        )
                    }
                } header: {
                    Text("Clipboard")
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
                    Text("Requires the 1Password CLI signed in.")
                }

                Section {
                    LabeledContent("System Keychain") {
                        Text("`vibevault import --from keychain`")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Other CLI sources")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .background(PremiumBackdrop())
        .navigationTitle("Import Secrets")
        .sheet(item: $reviewSheet) { payload in
            ImportReviewSheet(
                subtitle: payload.subtitle,
                rows: payload.rows,
                notes: payload.notes,
                overwrite: overwrite
            )
            .environmentObject(env)
        }
    }

    private var importHero: some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .fill(Tokens.Palette.accent.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "square.and.arrow.down")
                    .font(.title3)
                    .foregroundStyle(Tokens.Palette.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Bring secrets into the vault")
                    .font(.headline)
                Text("Clipboard, dotenv, shell env, or 1Password CLI.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.xxl)
        .padding(.vertical, Tokens.Space.lg)
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
                openDotenvReview(url)
            }
        }
    }

    private func openDotenvReview(_ url: URL) {
        do {
            let items = try DotenvImporter.parseFile(at: url)
            guard !items.isEmpty else {
                env.importStatus = "No secrets found in \(url.lastPathComponent)"
                return
            }
            reviewSheet = ImportReviewPayload(
                subtitle: url.path,
                rows: ImportRowState.from(items, sourceFile: url.lastPathComponent),
                notes: "imported from \(url.lastPathComponent)"
            )
        } catch {
            env.importStatus = "error: \(error)"
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
