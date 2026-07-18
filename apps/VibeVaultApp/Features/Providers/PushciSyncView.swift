import SwiftUI
import AppKit
import VaultCore

struct PushciSyncView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var projectPath = ""
    @State private var reconcile: ProviderNameReconcile?
    @State private var selected: Set<String> = []
    @State private var phase: Phase = .idle
    @State private var statusMessage: String?

    enum Phase { case idle, reconciling, pushing }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                PushciConnectionCard(
                    projectPath: $projectPath,
                    cliReady: env.pushciScopeComplete,
                    lastScannedPath: env.lastScannedURL?.path,
                    onSetup: handleSetup
                )
                actionRow
                if let msg = statusMessage { ImportStatusBanner(message: msg) }
                if let reconcile {
                    CloudflareReconcilePanel(reconcile: reconcile, selectedWorkerNames: $selected)
                }
                Text("Local-only: secrets encrypted per machine. Cloud sync API coming to pushci.dev.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
            }
            .padding(Tokens.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("PushCI")
        .onAppear { loadScope() }
        .onChange(of: projectPath) { _, v in env.setPushciProjectPath(v) }
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
        }
    }

    private var canSync: Bool {
        !projectPath.isEmpty && FileManager.default.fileExists(atPath: projectPath)
    }

    private func handleSetup() {
        if projectPath.isEmpty, let last = env.lastScannedURL?.path, !last.isEmpty {
            projectPath = last
            env.toastMessage = "Using last scanned project"
            return
        }
        if projectPath.isEmpty {
            env.toastMessage = "Enter a project path (folder with pushci init)"
            return
        }
        if let url = URL(string: "https://pushci.dev/docs") {
            NSWorkspace.shared.open(url)
        }
        env.toastMessage = "Install CLI: brew install pushci"
    }

    private func loadScope() {
        projectPath = env.settings.pushciProjectPath.isEmpty
            ? (env.lastScannedURL?.path ?? "")
            : env.settings.pushciProjectPath
    }

    @MainActor
    private func runReconcile() async {
        phase = .reconciling
        statusMessage = nil
        defer { phase = .idle }
        do {
            let r = try await env.reconcilePushci()
            reconcile = r
            selected = r.extraLocally
            statusMessage = "Compared \(r.remoteNames.count) PushCI · \(r.localNames.count) vault"
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
            let result = try await env.pushToPushci(names: selected)
            statusMessage = "Pushed \(result.pushed.count) · failed \(result.failed.count)"
            env.refresh()
            await runReconcile()
        } catch {
            statusMessage = "Error: \(error)"
        }
    }
}
