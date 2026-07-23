import AppKit
import SwiftUI
import VaultCore

struct SecretDetailView: View {
    @EnvironmentObject var env: AppEnvironment
    let secret: Secret
    @State private var deleteConfirm = false
    @State private var showRotateSheet = false
    @State private var showTOTPSheet = false
    @State private var unlockedTOTPAuthURL: String?

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
        .navigationTitle(currentSecret.name)
        .navigationSubtitle(currentSecret.updatedAt.formatted(.relative(presentation: .named)))
        .confirmationDialog(
            "Delete \(currentSecret.name)?",
            isPresented: $deleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { env.deleteSecret(name: currentSecret.name) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes the secret from your local vault. Cloud provider copies are not revoked.")
        }
        .sheet(isPresented: $showRotateSheet) {
            RotateSheetView(secret: currentSecret, isPresented: $showRotateSheet)
                .environmentObject(env)
        }
        .sheet(isPresented: $showTOTPSheet) {
            TOTPSetupSheet(secretName: currentSecret.name, unlockedAuthURL: $unlockedTOTPAuthURL)
                .environmentObject(env)
        }
    }

    private var currentSecret: Secret {
        env.secrets.first(where: { $0.name == secret.name }) ?? secret
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.md) {
                Text(currentSecret.name)
                    .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
                    .tracking(-0.5)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Button {
                    env.copySecretName(currentSecret.name)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Tokens.Text.secondary)
                .help("Copy key name")
                .accessibilityLabel("Copy key name")
                Spacer()
                SecretBadgeStrip(secret: currentSecret)
            }
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(Tokens.Text.tertiary)
                Text("Updated \(currentSecret.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.subheadline)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            SecretValueRow(secret: currentSecret)
                .environmentObject(env)
                .padding(.top, Tokens.Space.xs)
        }
    }

    private var detailSurface: some View {
        VStack(spacing: 0) {
            row("Updated", currentSecret.updatedAt.formatted(date: .abbreviated, time: .standard))
            if let last = currentSecret.lastRotatedAt {
                Divider().padding(.leading, Tokens.Space.md)
                row("Last rotated", last.formatted(date: .abbreviated, time: .omitted))
            }
            if let exp = currentSecret.expiresAt {
                Divider().padding(.leading, Tokens.Space.md)
                row("Expires", exp.formatted(date: .abbreviated, time: .omitted))
            }
            if let every = currentSecret.rotateEveryDays {
                Divider().padding(.leading, Tokens.Space.md)
                row("Rotate every", "\(every) days")
            }
            if let due = currentSecret.rotationDueAt {
                Divider().padding(.leading, Tokens.Space.md)
                row("Rotation due", due.formatted(date: .abbreviated, time: .omitted))
            }
            if let notes = currentSecret.notes, !notes.isEmpty {
                Divider().padding(.leading, Tokens.Space.md)
                row("Notes", notes)
            }
            Divider().padding(.leading, Tokens.Space.md)
            TOTPDetailRow(
                secret: currentSecret,
                unlockedAuthURL: unlockedTOTPAuthURL,
                unlock: { Task { await unlockTOTP(openManager: false) } },
                manage: { manageTOTP() },
                copy: { code in copyTOTPCode(code) }
            )
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
            get: { currentSecret.mcpAllowed },
            set: { v in Task { await env.setMCPAllowed(name: currentSecret.name, allowed: v) } }
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
            try await env.service.rotate(name: currentSecret.name, newValue: nil)
            env.refresh()
        } catch { env.lastError = "\(error)" }
    }

    private func unlockTOTP(openManager: Bool) async {
        do {
            let fresh = try await env.service.read(name: currentSecret.name, reason: "Show MFA code for \(currentSecret.name)")
            unlockedTOTPAuthURL = fresh.totpAuthURL
            if openManager { showTOTPSheet = true }
        } catch {
            env.lastError = "\(error)"
            env.showToast("Could not unlock MFA", feedback: .caution)
        }
    }

    private func manageTOTP() {
        if unlockedTOTPAuthURL != nil || !currentSecret.hasTOTP {
            showTOTPSheet = true
        } else {
            Task { await unlockTOTP(openManager: true) }
        }
    }

    private func copyTOTPCode(_ code: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        env.showToast("Copied MFA code")
    }
}

private struct TOTPDetailRow: View {
    let secret: Secret
    let unlockedAuthURL: String?
    let unlock: () -> Void
    let manage: () -> Void
    let copy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(alignment: .center) {
                Label("MFA code", systemImage: "number.square")
                    .foregroundStyle(Tokens.Text.secondary)
                Spacer()
                Button(secret.hasTOTP ? "Manage" : "Add") { manage() }
                    .buttonStyle(.borderless)
            }
            content
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.md)
    }

    @ViewBuilder
    private var content: some View {
        if let unlockedAuthURL {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let code = try? TOTPGenerator.code(from: unlockedAuthURL, at: context.date) {
                    VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                        HStack(spacing: Tokens.Space.md) {
                            Text(grouped(code.code))
                                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                                .textSelection(.enabled)
                            Button {
                                copy(code.code)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                            .help("Copy MFA code")
                            Spacer()
                            Text("\(code.secondsRemaining)s")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Tokens.Text.secondary)
                        }
                        ProgressView(value: Double(code.secondsRemaining), total: Double(code.period))
                            .tint(Tokens.Palette.accent)
                    }
                } else {
                    Text("MFA setup key could not be read.")
                        .font(.caption)
                        .foregroundStyle(Tokens.Status.warning)
                }
            }
        } else if secret.hasTOTP {
            HStack {
                Text("Attached. Unlock to view the current code.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
                Spacer()
                Button("Unlock") { unlock() }
                    .buttonStyle(.bordered)
            }
        } else {
            Text("No rotating code attached.")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
        }
    }

    private func grouped(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }
}

private struct TOTPSetupSheet: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    let secretName: String
    @Binding var unlockedAuthURL: String?
    @State private var setupValue: String

    init(secretName: String, unlockedAuthURL: Binding<String?>) {
        self.secretName = secretName
        _unlockedAuthURL = unlockedAuthURL
        _setupValue = State(initialValue: unlockedAuthURL.wrappedValue ?? "")
    }

    var body: some View {
        Form {
            Section {
                TextField("Setup key or otpauth:// URL", text: $setupValue)
                    .font(.system(.body, design: .monospaced))
                if !setupValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, normalized == nil {
                    Text("Enter a valid authenticator setup key or otpauth URL.")
                        .font(.caption)
                        .foregroundStyle(Tokens.Status.warning)
                }
            } header: {
                Text("MFA code")
            } footer: {
                Text("The setup key is stored with this credential and only revealed after authentication.")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 240)
        .navigationTitle("MFA code")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Remove") {
                    Task {
                        await env.setTOTP(name: secretName, authURL: nil)
                        unlockedAuthURL = nil
                        dismiss()
                    }
                }
                .disabled(unlockedAuthURL == nil)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let normalized else { return }
                    Task {
                        await env.setTOTP(name: secretName, authURL: normalized)
                        unlockedAuthURL = normalized
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(normalized == nil)
            }
        }
    }

    private var normalized: String? {
        try? TOTPGenerator.normalizedAuthURL(from: setupValue, label: secretName)
    }
}
