import SwiftUI
import VaultCore

/// Value history for one secret, with rollback. Values stay masked — restoring
/// is a Touch ID-gated write, never a plaintext reveal.
struct HistorySheetView: View {
    @EnvironmentObject var env: AppEnvironment
    let secret: Secret
    @Binding var isPresented: Bool
    @State private var versions: [SecretVersion] = []
    @State private var confirmRestore: SecretVersion?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            header
            if versions.isEmpty {
                emptyState
            } else {
                ScrollView { list }
            }
            HStack {
                Spacer()
                Button("Done") { isPresented = false }.buttonStyle(.glassProminent)
            }
        }
        .padding(Tokens.Space.xxl)
        .frame(width: 460, height: 420)
        .background(LiquidBackdrop())
        .onAppear { versions = env.historyVersions(name: secret.name) }
        .confirmationDialog(
            "Restore this value?",
            isPresented: Binding(get: { confirmRestore != nil }, set: { if !$0 { confirmRestore = nil } }),
            titleVisibility: .visible
        ) {
            Button("Restore", role: .destructive) {
                if let v = confirmRestore {
                    Task { await env.rollback(name: secret.name, to: v); refresh() }
                }
            }
            Button("Cancel", role: .cancel) { confirmRestore = nil }
        } message: {
            Text("The current value is saved to history first, so you can undo this.")
        }
    }

    private func refresh() { versions = env.historyVersions(name: secret.name) }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text("History").font(.title2.weight(.semibold))
            Text(secret.name)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(Tokens.Text.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Tokens.Space.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle).foregroundStyle(Tokens.Text.tertiary)
            Text("No previous values yet")
                .foregroundStyle(Tokens.Text.secondary)
            Text("Rotating or editing this secret records the prior value here.")
                .font(.caption).foregroundStyle(Tokens.Text.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(versions.enumerated()), id: \.element.id) { idx, v in
                if idx > 0 { Divider().padding(.leading, Tokens.Space.md) }
                row(v, isLatest: idx == 0)
            }
        }
        .glassPanel(radius: Tokens.Radius.lg)
    }

    private func row(_ v: SecretVersion, isLatest: Bool) -> some View {
        HStack(spacing: Tokens.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(v.maskedValue)
                    .font(.system(.body, design: .monospaced))
                Text(v.savedAt.formatted(.relative(presentation: .named)))
                    .font(.caption).foregroundStyle(Tokens.Text.secondary)
            }
            Spacer()
            Button("Restore") { confirmRestore = v }
                .buttonStyle(.glass)
                .help("Make this the current value")
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.md)
    }
}
