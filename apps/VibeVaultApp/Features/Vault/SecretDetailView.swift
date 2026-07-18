import SwiftUI
import VaultCore

struct SecretDetailView: View {
    @EnvironmentObject var env: AppEnvironment
    let secret: Secret
    @State private var deleteConfirm = false
    @State private var showRotateSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                hero
                detailSurface
                actions
            }
            .padding(.horizontal, Tokens.Space.xxl)
            .padding(.top, Tokens.Space.xxl)
            .padding(.bottom, Tokens.Space.xxxl)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(PremiumBackdrop())
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
            SecretValueRow(secret: secret)
                .environmentObject(env)
                .padding(.top, Tokens.Space.xs)
        }
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
        .background(Tokens.Surface.elevated, in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.Surface.separator.opacity(0.6), lineWidth: Tokens.Stroke.hairline)
        )
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

    private var actions: some View {
        HStack(spacing: Tokens.Space.sm) {
            Button { showRotateSheet = true } label: {
                Label("Rotate value…", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            Button { Task { await markRotated() } } label: {
                Label("Mark rotated now", systemImage: "checkmark.circle")
            }
            .help("Records rotation without changing the value.")
            Spacer()
            Button(role: .destructive) { deleteConfirm = true } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func markRotated() async {
        do {
            try await env.service.rotate(name: secret.name, newValue: nil)
            env.refresh()
        } catch { env.lastError = "\(error)" }
    }
}
