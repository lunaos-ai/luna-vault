import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VaultCore

struct ImportView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var overwrite = false
    @State private var envGlobs = "CF_* STRIPE_* *_TOKEN *_API_KEY"
    @State private var opItemRef = ""
    @State private var opCLIStatus: String?
    @State private var imageOCRStatus: String?
    @State private var imageOCRRunning = false
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
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 156), spacing: Tokens.Space.sm)],
                        alignment: .leading,
                        spacing: Tokens.Space.sm
                    ) {
                        ForEach(PasswordManagerImportProfile.allCases) { profile in
                            PasswordAppImportButton(profile: profile) {
                                pickPasswordExport(profile: profile)
                            }
                        }
                    }

                    Divider()

                    HStack {
                        TextField("1Password item reference", text: $opItemRef, prompt: Text("Cloudflare API"))
                        Button("Review from op") {
                            openOnePasswordReview()
                        }
                        .disabled(opItemRef.isEmpty)
                    }

                    Button {
                        Task { opCLIStatus = await probeOpCLI() }
                    } label: {
                        Label("Check 1Password CLI", systemImage: "checkmark.circle")
                    }
                    if let s = opCLIStatus {
                        Text(s).font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Known password apps")
                } footer: {
                    Text("Use exported CSV files for Apple Passwords, Bitwarden, 1Password, LastPass, and Dashlane. Direct 1Password import uses the signed-in `op` CLI.")
                }

                Section {
                    Button {
                        pickCredentialImage()
                    } label: {
                        Label(
                            imageOCRRunning ? "Reading image…" : "Choose screenshot or image…",
                            systemImage: "doc.viewfinder"
                        )
                    }
                    .disabled(imageOCRRunning)
                    if let status = imageOCRStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Screenshots")
                } footer: {
                    Text("Reads visible credential labels from screenshots, then lets you review and rename every candidate before import.")
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
                Text("Clipboard, screenshots, dotenv, shell env, or 1Password CLI.")
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

    private func pickPasswordExport(profile: PasswordManagerImportProfile) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = []
        panel.treatsFilePackagesAsDirectories = true
        panel.begin { resp in
            if resp == .OK, let url = panel.url {
                openPasswordExportReview(url, profile: profile)
            }
        }
    }

    private func pickCredentialImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.treatsFilePackagesAsDirectories = true
        panel.begin { resp in
            if resp == .OK, let url = panel.url {
                openCredentialImageReview(url)
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

    private func openPasswordExportReview(_ url: URL, profile: PasswordManagerImportProfile) {
        do {
            let items = try PasswordManagerCSVImporter.parseFile(at: url, profile: profile)
            guard !items.isEmpty else {
                env.importStatus = "No passwords found in \(url.lastPathComponent)"
                return
            }
            reviewSheet = ImportReviewPayload(
                subtitle: "\(profile.label) · \(url.lastPathComponent)",
                rows: ImportRowState.from(items, sourceFile: url.lastPathComponent),
                notes: "imported from \(profile.label) export"
            )
        } catch {
            env.importStatus = "error: \(error)"
        }
    }

    private func openCredentialImageReview(_ url: URL) {
        imageOCRRunning = true
        imageOCRStatus = "Reading \(url.lastPathComponent)…"
        Task {
            do {
                let items = try await Task.detached {
                    try ImageCredentialImporter.recognizeFile(at: url)
                }.value
                imageOCRRunning = false
                guard !items.isEmpty else {
                    imageOCRStatus = "No credential fields found in \(url.lastPathComponent)"
                    return
                }
                imageOCRStatus = "Found \(items.count) candidate\(items.count == 1 ? "" : "s")"
                reviewSheet = ImportReviewPayload(
                    subtitle: "Image OCR · \(url.lastPathComponent)",
                    rows: ImportRowState.from(items, sourceFile: url.lastPathComponent),
                    notes: "imported from image OCR: \(url.lastPathComponent)"
                )
            } catch {
                imageOCRRunning = false
                imageOCRStatus = "error: \(error)"
                env.importStatus = "error: \(error)"
            }
        }
    }

    private func openOnePasswordReview() {
        do {
            let items = try OnePasswordImporter.fetch(itemRef: opItemRef)
            guard !items.isEmpty else {
                env.importStatus = "No fields found in 1Password item"
                return
            }
            reviewSheet = ImportReviewPayload(
                subtitle: "1Password CLI · \(opItemRef)",
                rows: ImportRowState.from(items),
                notes: "imported from 1Password: \(opItemRef)"
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

private struct PasswordAppImportButton: View {
    let profile: PasswordManagerImportProfile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Image(systemName: profile.systemImage)
                    .font(.title3)
                    .foregroundStyle(profile.tint)
                Text(profile.label)
                    .font(.subheadline.weight(.semibold))
                Text(profile.subtitle)
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .padding(Tokens.Space.md)
            .background(
                Tokens.Surface.elevated.opacity(0.7),
                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                    .strokeBorder(Tokens.Surface.separator.opacity(0.5), lineWidth: Tokens.Stroke.hairline)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension PasswordManagerImportProfile {
    var subtitle: String {
        switch self {
        case .auto: return "CSV from any app"
        case .applePasswords: return "Passwords export"
        case .bitwarden: return "Vault CSV"
        case .onePasswordCSV: return "CSV export"
        case .lastPass: return "CSV export"
        case .dashlane: return "CSV export"
        }
    }

    var systemImage: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .applePasswords: return "apple.logo"
        case .bitwarden: return "shield"
        case .onePasswordCSV: return "1.circle"
        case .lastPass: return "ellipsis.rectangle"
        case .dashlane: return "bolt.shield"
        }
    }

    var tint: Color {
        switch self {
        case .auto: return Tokens.Palette.accent
        case .applePasswords: return Tokens.Text.primary
        case .bitwarden: return Tokens.Status.info
        case .onePasswordCSV: return Tokens.Palette.mint
        case .lastPass: return Tokens.Palette.rose
        case .dashlane: return Tokens.Palette.warm
        }
    }
}
