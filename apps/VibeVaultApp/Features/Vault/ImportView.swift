import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VaultCore

struct ImportView: View {
    @EnvironmentObject var env: AppEnvironment
    @State var overwrite = false
    @State var envGlobs = "CF_* STRIPE_* *_TOKEN *_API_KEY"
    @State var opItemRef = ""
    @State var opCLIStatus: String?
    @State var imageOCRStatus: String?
    @State var imageOCRRunning = false
    @State var reviewSheet: ImportReviewPayload?

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
                    .padding(.top, Tokens.Space.md)
                    .padding(.bottom, Tokens.Space.xs)
            }
            importHero
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                    CompactImportSection(
                        title: "Options",
                        footer: "When off, secrets that already exist in your vault are skipped."
                    ) {
                        HStack(spacing: Tokens.Space.md) {
                            Text("Overwrite existing")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Toggle("", isOn: $overwrite)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }

                    CompactImportSection(
                        title: "Known password apps",
                        footer: "Use exported CSV files for Apple Passwords, Bitwarden, 1Password, LastPass, and Dashlane. Direct 1Password import uses the signed-in op CLI."
                    ) {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 148), spacing: Tokens.Space.sm)],
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

                        HStack(spacing: Tokens.Space.sm) {
                            TextField("1Password item reference", text: $opItemRef, prompt: Text("Cloudflare API"))
                            Button("Review from op") {
                                openOnePasswordReview()
                            }
                            .disabled(opItemRef.isEmpty)
                        }

                        HStack(spacing: Tokens.Space.sm) {
                            Button {
                                Task { opCLIStatus = await probeOpCLI() }
                            } label: {
                                Label("Check 1Password CLI", systemImage: "checkmark.circle")
                            }
                            if let s = opCLIStatus {
                                Text(s)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }

                    CompactImportSection(
                        title: "Screenshots",
                        footer: "Reads visible credential labels from screenshots, then lets you review and rename every candidate before import."
                    ) {
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
                    }

                    CompactImportSection(title: "Clipboard") {
                        ClipboardImportSection(overwrite: overwrite) { items in
                            reviewSheet = ImportReviewPayload(
                                subtitle: "Clipboard",
                                rows: ImportRowState.from(items),
                                notes: "imported from clipboard"
                            )
                        }
                    }

                    CompactImportSection(title: "Files") {
                        HStack(spacing: Tokens.Space.md) {
                            Text(".env file")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Button("Choose…") { pickDotenv() }
                        }
                        Text("Comments and export prefixes handled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    CompactImportSection(
                        title: "Shell environment",
                        footer: "Pulls secrets from your current shell env matching any glob."
                    ) {
                        HStack(spacing: Tokens.Space.sm) {
                            TextField("Globs", text: $envGlobs, prompt: Text("CF_* STRIPE_*"))
                                .font(.system(.body, design: .monospaced))
                            Button("Import from environment") {
                                let globs = envGlobs.split(separator: " ").map(String.init)
                                env.importEnv(globs: globs, overwrite: overwrite)
                            }
                        }
                    }

                    CompactImportSection(title: "Other CLI sources") {
                        HStack(spacing: Tokens.Space.md) {
                            Text("System Keychain")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("vibevault import --from keychain")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, Tokens.Space.xxl)
                .padding(.bottom, Tokens.Space.xxl)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
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

}
