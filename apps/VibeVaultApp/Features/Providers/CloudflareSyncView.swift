import SwiftUI
import VaultCore

struct CloudflareSyncView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var accountId = ""
    @State private var scriptName = ""
    @State private var reconcile: CloudflareReconcile?
    @State private var selectedWorkerNames: Set<String> = []
    @State private var phase: SyncPhase = .idle
    @State private var statusMessage: String?
    @State private var showTokenSetup = false

    enum SyncPhase { case idle, reconciling, pushing }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                CloudflareConnectionCard(
                    accountId: $accountId,
                    scriptName: $scriptName,
                    tokenReady: env.hasCloudflareToken,
                    wranglerDetected: env.cloudflareScopeComplete,
                    onSetup: { showTokenSetup = true }
                )
                actionRow
                if let msg = statusMessage { ImportStatusBanner(message: msg) }
                if let reconcile { reconcilePanel(reconcile) }
                helpFooter
            }
            .padding(Tokens.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PremiumBackdrop())
        .navigationTitle("Cloudflare")
        .onAppear { loadScope() }
        .onChange(of: accountId) { _, v in env.setCloudflareScope(accountId: v, scriptName: scriptName) }
        .onChange(of: scriptName) { _, v in env.setCloudflareScope(accountId: accountId, scriptName: v) }
        .sheet(isPresented: $showTokenSetup) {
            ProviderTokenSetupSheet(
                title: "Cloudflare API token",
                prompt: "Paste API token",
                dashboardURL: URL(string: "https://dash.cloudflare.com/profile/api-tokens")!,
                dashboardLabel: "Create token in Cloudflare dashboard",
                footer: "Needs Workers Scripts:Edit for the target script. Stored in Keychain."
            ) { token in
                env.setCloudflareToken(token)
                env.toastMessage = "Cloudflare token saved"
            }
        }
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
            .disabled(!canSync || selectedWorkerNames.isEmpty || phase != .idle)
            Spacer()
            if !env.hasCloudflareToken {
                Button("Add API token…") { showTokenSetup = true }
                    .font(.caption)
                    .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private func reconcilePanel(_ r: CloudflareReconcile) -> some View {
        CloudflareReconcilePanel(reconcile: r, selectedWorkerNames: $selectedWorkerNames)
    }

    private var helpFooter: some View {
        Text("Pulls secret names from the Workers API. Values cannot be read back from Cloudflare. Push sends vault values as Worker secrets.")
            .font(.caption)
            .foregroundStyle(Tokens.Text.tertiary)
    }

    private var canSync: Bool {
        env.hasCloudflareToken && !accountId.isEmpty && !scriptName.isEmpty
    }

    private func loadScope() {
        accountId = env.settings.cloudflareAccountId
        scriptName = env.settings.cloudflareScriptName
    }

    @MainActor
    private func runReconcile() async {
        phase = .reconciling
        statusMessage = nil
        defer { phase = .idle }
        do {
            let r = try await env.reconcileCloudflare()
            reconcile = r
            selectedWorkerNames = r.extraLocally
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
            let vaultNames = env.vaultNames(matchingWorker: selectedWorkerNames)
            let result = try await env.pushToCloudflare(vaultNames: vaultNames)
            statusMessage = "Pushed \(result.pushed.count) · failed \(result.failed.count)"
            env.refresh()
            await runReconcile()
        } catch {
            statusMessage = "Error: \(error)"
        }
    }
}
