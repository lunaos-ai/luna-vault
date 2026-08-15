import SwiftUI
import VaultCore

struct AuthenticatorDetailView: View {
    @EnvironmentObject var env: AppEnvironment
    let account: AuthenticatorAccountMetadata
    @State private var currentCode: String?
    @State private var errorText: String?
    @State private var showDelete = false
    @State private var showRecoveryImport = false
    @State private var revealedRecoveryCode: RecoveryCode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                HStack {
                    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                        Text(account.issuer)
                            .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
                        Text(account.accountName).foregroundStyle(Tokens.Text.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await env.toggleAuthenticatorFavorite(account) }
                    } label: {
                        Image(systemName: account.favorite ? "star.fill" : "star")
                    }
                    .accessibilityLabel(account.favorite ? "Remove favorite" : "Add favorite")
                }
                codeSurface
                recoverySurface
                HStack {
                    Spacer()
                    Button(role: .destructive) { showDelete = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .padding(Tokens.Space.xxl)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .task(id: account.id) { await refreshCodeLoop() }
        .confirmationDialog("Delete \(account.issuer)?", isPresented: $showDelete) {
            Button("Delete", role: .destructive) {
                Task { await env.deleteAuthenticator(id: account.id) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showRecoveryImport) {
            RecoveryCodesSheet(accountID: account.id).environmentObject(env)
        }
    }

    private var codeSurface: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("CURRENT CODE").font(.caption.weight(.semibold)).tracking(0.5)
            if let currentCode {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = secondsRemaining(at: context.date)
                    HStack {
                        Text(grouped(currentCode))
                            .font(.system(size: 36, weight: .semibold, design: .monospaced))
                            .textSelection(.enabled)
                        Button { env.copyAuthenticatorValue(currentCode) } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        Spacer()
                        Text("\(remaining)s").font(.body.monospacedDigit())
                    }
                    ProgressView(value: Double(remaining), total: Double(account.period))
                        .tint(Tokens.Palette.accent)
                }
            } else if let errorText {
                Text(errorText).foregroundStyle(.secondary)
                Button("Try again") { Task { await loadCode() } }
            } else {
                ProgressView("Unlocking…")
            }
        }
        .padding(Tokens.Space.lg)
        .background(Tokens.Surface.elevated, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
            .stroke(Tokens.Surface.separator, lineWidth: Tokens.Stroke.hairline))
    }

    private var recoverySurface: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                Text("Recovery codes").font(.headline)
                Spacer()
                Text("\(account.unusedRecoveryCodeCount) remaining").foregroundStyle(.secondary)
            }
            if let revealedRecoveryCode {
                HStack {
                    Text(revealedRecoveryCode.value).font(.system(.body, design: .monospaced))
                    Spacer()
                    Button("Copy") { env.copyAuthenticatorValue(revealedRecoveryCode.value) }
                    Button("Mark used") { Task { await markUsed(revealedRecoveryCode) } }
                }
            }
            HStack {
                Button("Reveal next") { Task { await revealNextRecoveryCode() } }
                    .disabled(account.unusedRecoveryCodeCount == 0)
                Button("Import codes") { showRecoveryImport = true }
            }
        }
    }

    private func refreshCodeLoop() async {
        while !Task.isCancelled {
            await loadCode()
            let delay = UInt64(max(1, secondsRemaining(at: Date()))) * 1_000_000_000
            try? await Task.sleep(nanoseconds: delay)
        }
    }

    private func loadCode() async {
        do {
            currentCode = try await env.authenticatorService.code(id: account.id).code
            errorText = nil
        } catch { errorText = "\(error)" }
    }

    private func secondsRemaining(at date: Date) -> Int {
        account.period - Int(date.timeIntervalSince1970) % account.period
    }

    private func revealNextRecoveryCode() async {
        do { revealedRecoveryCode = try await env.authenticatorService.nextRecoveryCode(id: account.id) }
        catch { env.lastError = "\(error)" }
    }

    private func markUsed(_ code: RecoveryCode) async {
        do {
            try await env.authenticatorService.markRecoveryCodeUsed(
                id: account.id, recoveryCodeID: code.id
            )
            revealedRecoveryCode = nil
            env.refreshAuthenticators()
        } catch { env.lastError = "\(error)" }
    }

    private func grouped(_ code: String) -> String {
        let middle = code.index(code.startIndex, offsetBy: code.count / 2)
        return "\(code[..<middle]) \(code[middle...])"
    }
}
