import SwiftUI
import VaultCore

struct CloudflareSyncBar: View {
    @EnvironmentObject var env: AppEnvironment
    let projectURL: URL
    let onOpenCloudflare: () -> Void

    @State private var reconcile: CloudflareReconcile?
    @State private var pushing = false
    @State private var status: String?

    private var wrangler: WranglerConfig { WranglerConfig.load(from: projectURL) }
    private var canSync: Bool { env.hasCloudflareToken && env.cloudflareScopeComplete }

    var body: some View {
        if wrangler.isComplete || env.cloudflareScopeComplete {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: "cloud.fill")
                        .foregroundStyle(Tokens.Palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cloudflare Workers")
                            .font(.subheadline.weight(.semibold))
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Tokens.Text.secondary)
                    }
                    Spacer()
                    if pushing {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Check") { Task { await check() } }
                            .buttonStyle(.bordered)
                            .disabled(!canSync)
                        Button(pushLabel) { Task { await pushAll() } }
                            .buttonStyle(.borderedProminent)
                            .tint(Tokens.Palette.accent)
                            .disabled(!canSync || pushCount == 0)
                    }
                }
                if let status {
                    Text(status).font(.caption).foregroundStyle(Tokens.Text.secondary)
                }
                Button("Open Cloudflare sync") { onOpenCloudflare() }
                    .font(.caption)
                    .buttonStyle(.link)
            }
            .padding(Tokens.Space.md)
            .background(Tokens.Palette.accent.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .strokeBorder(Tokens.Palette.accent.opacity(0.2), lineWidth: Tokens.Stroke.hairline)
            )
            .task { if canSync { await check() } }
        }
    }

    private var subtitle: String {
        let script = env.settings.cloudflareScriptName.isEmpty
            ? (wrangler.scriptName ?? "worker") : env.settings.cloudflareScriptName
        if !canSync { return "\(script) · add API token in Settings" }
        if let r = reconcile, r.extraLocally.count > 0 {
            return "\(script) · \(r.extraLocally.count) to push"
        }
        return "\(script) · ready"
    }

    private var pushCount: Int { reconcile?.extraLocally.count ?? 0 }
    private var pushLabel: String { pushCount > 0 ? "Push \(pushCount)" : "Push" }

    @MainActor
    private func check() async {
        do {
            reconcile = try await env.reconcileCloudflare(projectURL: projectURL)
        } catch {
            status = "\(error)"
        }
    }

    @MainActor
    private func pushAll() async {
        guard let r = reconcile, !r.extraLocally.isEmpty else { return }
        pushing = true
        status = nil
        defer { pushing = false }
        do {
            let vaultNames = env.vaultNames(matchingWorker: r.extraLocally, projectURL: projectURL)
            let result = try await env.pushToCloudflare(vaultNames: vaultNames)
            status = "Pushed \(result.pushed.count) to Workers"
            env.refresh()
            await check()
        } catch {
            status = "\(error)"
        }
    }
}
