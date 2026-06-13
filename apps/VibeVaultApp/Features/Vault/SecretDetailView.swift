import SwiftUI
import VaultCore

struct SecretDetailView: View {
    @EnvironmentObject var env: AppEnvironment
    let secret: Secret
    @State private var revealed = false
    @State private var revealedValue = ""
    @State private var deleteConfirm = false
    @State private var showRotateSheet = false
    @State private var showHistory = false
    @State private var showExport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                hero.glassCard(radius: Tokens.Radius.lg, elevation: .lifted)
                detailSurface
                SecretActionsBar(
                    secret: secret,
                    showRotate: $showRotateSheet,
                    showHistory: $showHistory,
                    showExport: $showExport,
                    deleteConfirm: $deleteConfirm
                )
            }
            .padding(.horizontal, Tokens.Space.xxl)
            .padding(.top, Tokens.Space.xxl)
            .padding(.bottom, Tokens.Space.xxxl)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(LiquidBackdrop())
        .navigationTitle(secret.name)
        .navigationSubtitle(secret.updatedAt.formatted(.relative(presentation: .named)))
        .confirmationDialog(
            "Delete \(secret.name)?",
            isPresented: $deleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { env.deleteSecret(name: secret.name) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes the secret from your local Keychain. Cloud provider copies are not revoked.")
        }
        .sheet(isPresented: $showRotateSheet) {
            RotateSheetView(secret: secret, isPresented: $showRotateSheet)
                .environmentObject(env)
        }
        .sheet(isPresented: $showHistory) {
            HistorySheetView(secret: secret, isPresented: $showHistory)
                .environmentObject(env)
        }
        .sheet(isPresented: $showExport) {
            EnvExportView(names: [secret.name], isPresented: $showExport)
                .environmentObject(env)
        }
        // Never let a revealed value bleed across to another secret.
        .onChange(of: secret.id) { _, _ in hideValue() }
        .onDisappear { hideValue() }
    }

    private func hideValue() {
        revealed = false
        revealedValue = ""
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.md) {
                Text(secret.name)
                    .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
                    .tracking(-0.5)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Spacer()
                SecretBadgeStrip(secret: secret)
            }
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(Tokens.Text.tertiary)
                Text("Updated \(secret.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.subheadline)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            valueRow.padding(.top, Tokens.Space.xs)
        }
    }

    private var valueRow: some View {
        HStack(spacing: Tokens.Space.md) {
            Text(revealed ? revealedValue : secret.maskedValue)
                .font(.system(.title3, design: .monospaced).weight(.medium))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { Task { await reveal() } } label: {
                Image(systemName: revealed ? "eye.slash" : "eye")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Tokens.Text.secondary)
            .help(revealed ? "Hide value" : "Reveal value (Touch ID)")
            Button { copy() } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Tokens.Text.secondary)
            .help("Copy value (Touch ID)")
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.lg)
        .deepInset(radius: Tokens.Radius.md)
    }

    private var detailSurface: some View {
        VStack(spacing: 0) {
            row("Updated", secret.updatedAt.formatted(date: .abbreviated, time: .standard))
            if let last = secret.lastRotatedAt {
                Divider().padding(.leading, Tokens.Space.md)
                row("Last rotated", last.formatted(date: .abbreviated, time: .omitted))
            }
            if let exp = secret.expiresAt {
                Divider().padding(.leading, Tokens.Space.md)
                row("Expires", exp.formatted(date: .abbreviated, time: .omitted))
            }
            if let every = secret.rotateEveryDays {
                Divider().padding(.leading, Tokens.Space.md)
                row("Rotate every", "\(every) days")
            }
            if let due = secret.rotationDueAt {
                Divider().padding(.leading, Tokens.Space.md)
                row("Rotation due", due.formatted(date: .abbreviated, time: .omitted))
            }
            if let notes = secret.notes, !notes.isEmpty {
                Divider().padding(.leading, Tokens.Space.md)
                row("Notes", notes)
            }
            Divider().padding(.leading, Tokens.Space.md)
            accessRow
        }
        .glassPanel(radius: Tokens.Radius.lg)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Tokens.Text.secondary)
            Spacer()
            Text(value).foregroundStyle(Tokens.Text.primary).multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.md)
    }

    private var accessRow: some View {
        Toggle(isOn: Binding(
            get: { secret.mcpAllowed },
            set: { v in Task { await env.setMCPAllowed(name: secret.name, allowed: v) } }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Allow AI agents (MCP)")
                Text("Claude Code, Cursor, and others can read this. Every read is audited.")
                    .font(.caption).foregroundStyle(Tokens.Text.secondary)
            }
        }
        .toggleStyle(.switch)
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.md)
    }

    private func reveal() async {
        if revealed { revealed = false; revealedValue = ""; return }
        let target = secret.id
        do {
            let fresh = try await env.service.read(name: secret.name, reason: "Reveal \(secret.name)")
            // Guard against a selection change while Touch ID was pending —
            // otherwise the prior secret's plaintext would surface under the new one.
            guard target == secret.id else { return }
            revealedValue = fresh.value
            revealed = true
        } catch { env.lastError = "\(error)" }
    }

    private func copy() {
        Task {
            do {
                let fresh = try await env.service.read(name: secret.name, reason: "Copy \(secret.name)")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(fresh.value, forType: .string)
            } catch { env.lastError = "\(error)" }
        }
    }

}
