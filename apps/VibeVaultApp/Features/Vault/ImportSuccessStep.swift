import SwiftUI
import VaultCore

struct ImportSuccessStep: View {
    @EnvironmentObject var env: AppEnvironment
    let importedCount: Int
    let subtitle: String?
    let highlightName: String?
    let projectURL: URL?
    let vaultNames: Set<String>
    let workerNames: Set<String>
    let onDone: () -> Void

    @State private var pushing = false
    @State private var pushStatus: String?

    private var wrangler: WranglerConfig? { projectURL.map { WranglerConfig.load(from: $0) } }
    private var scriptName: String {
        if !env.settings.cloudflareScriptName.isEmpty { return env.settings.cloudflareScriptName }
        return wrangler?.scriptName ?? "worker"
    }
    private var showsCloudflare: Bool {
        guard let w = wrangler else { return false }
        return w.isComplete || env.cloudflareScopeComplete
    }
    private var canPush: Bool { showsCloudflare && env.hasCloudflareToken && !vaultNames.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            successHeader
            if showsCloudflare, let url = projectURL { cloudflareCard(url) }
            footer
        }
    }

    private var successHeader: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Label("Imported \(importedCount) secret\(importedCount == 1 ? "" : "s")",
                  systemImage: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Tokens.Status.success)
            if let subtitle {
                Text(subtitle)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Tokens.Text.secondary)
            }
        }
    }

    @ViewBuilder
    private func cloudflareCard(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: "cloud.fill").foregroundStyle(Tokens.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Push to Cloudflare Workers?").font(.subheadline.weight(.semibold))
                    Text(cfSubtitle).font(.caption).foregroundStyle(Tokens.Text.secondary)
                }
            }
            if let pushStatus {
                Text(pushStatus).font(.caption).foregroundStyle(Tokens.Text.secondary)
            }
            HStack(spacing: Tokens.Space.sm) {
                if canPush {
                    Button { Task { await push(url) } } label: {
                        Label(pushing ? "Pushing…" : "Push \(workerNames.count) now",
                              systemImage: "icloud.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Tokens.Palette.accent)
                    .disabled(pushing)
                }
                Button("Open Cloudflare sync") { env.openCloudflare = true; onDone() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(Tokens.Space.lg)
        .background(Tokens.Palette.accent.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.Palette.accent.opacity(0.2), lineWidth: Tokens.Stroke.hairline)
        )
    }

    private var cfSubtitle: String {
        if !env.hasCloudflareToken { return "\(scriptName) · add API token in Settings to push" }
        return "Send \(workerNames.count) secret\(workerNames.count == 1 ? "" : "s") to \(scriptName)"
    }

    private var footer: some View {
        HStack {
            if let highlightName {
                Button("View in vault") {
                    env.focusVault(secretName: highlightName)
                    onDone()
                }
                .buttonStyle(.bordered)
            }
            Button("AI Agents") { env.openAIAgents = true; onDone() }
                .buttonStyle(.bordered)
            Spacer()
            Button("Done") { onDone() }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.Palette.accent)
                .keyboardShortcut(.defaultAction)
        }
    }

    @MainActor
    private func push(_ url: URL) async {
        pushing = true
        pushStatus = nil
        defer { pushing = false }
        env.updateCloudflareScope(from: url)
        do {
            let result = try await env.pushToCloudflare(vaultNames: vaultNames)
            pushStatus = "Pushed \(result.pushed.count) to Workers"
            env.refresh()
            if let scanned = env.lastScannedURL { env.scan(projectURL: scanned) }
        } catch {
            pushStatus = "\(error)"
        }
    }
}
