import SwiftUI
import VaultCore

struct VercelSyncView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var projectId = ""
    @State private var teamId = ""
    @State private var reconcile: ProviderNameReconcile?
    @State private var selected: Set<String> = []
    @State private var phase: Phase = .idle
    @State private var statusMessage: String?

    enum Phase { case idle, reconciling, pushing }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                VercelConnectionCard(
                    projectId: $projectId, teamId: $teamId, tokenReady: env.hasVercelToken
                )
                actionRow
                if let msg = statusMessage { ImportStatusBanner(message: msg) }
                if let reconcile {
                    CloudflareReconcilePanel(reconcile: reconcile, selectedWorkerNames: $selected)
                }
                Text("Pull lists env key names from Vercel. Push writes vault values as encrypted project env.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
            }
            .padding(Tokens.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PremiumBackdrop())
        .navigationTitle("Vercel")
        .onAppear { loadScope() }
        .onChange(of: projectId) { _, v in env.setVercelScope(projectId: v, teamId: teamId) }
        .onChange(of: teamId) { _, v in env.setVercelScope(projectId: projectId, teamId: v) }
    }

    private var actionRow: some View {
        HStack(spacing: Tokens.Space.sm) {
            Button { Task { await runReconcile() } } label: {
                Label(phase == .reconciling ? "Checking…" : "Check sync",
                      systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
            .disabled(!canSync || phase != .idle)
            Button { Task { await runPush() } } label: {
                Label(phase == .pushing ? "Pushing…" : "Push selected",
                      systemImage: "icloud.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .tint(Tokens.Palette.accent)
            .disabled(!canSync || selected.isEmpty || phase != .idle)
            Spacer()
            if !env.hasVercelToken {
                Text("Token in Settings → Vercel")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
            }
        }
    }

    private var canSync: Bool { env.hasVercelToken && !projectId.isEmpty }

    private func loadScope() {
        projectId = env.settings.vercelProjectId
        teamId = env.settings.vercelTeamId
    }

    @MainActor
    private func runReconcile() async {
        phase = .reconciling
        statusMessage = nil
        defer { phase = .idle }
        do {
            let r = try await env.reconcileVercel()
            reconcile = r
            selected = r.extraLocally
            statusMessage = "Compared \(r.remoteNames.count) remote · \(r.localNames.count) local"
        } catch {
            statusMessage = "Error: \(error)"
        }
    }

    @MainActor
    private func runPush() async {
        phase = .pushing
        statusMessage = nil
        defer { phase = .idle }
        do {
            let result = try await env.pushToVercel(names: selected)
            statusMessage = "Pushed \(result.pushed.count) · failed \(result.failed.count)"
            env.refresh()
            await runReconcile()
        } catch {
            statusMessage = "Error: \(error)"
        }
    }
}
