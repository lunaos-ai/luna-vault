import SwiftUI

/// Unlock once for the app session; Lock clears biometric trust + read cache.
struct SessionTrustSection: View {
    @EnvironmentObject var env: AppEnvironment

    var body: some View {
        Section {
            LabeledContent("Status", value: env.biometricStatus)
            HStack(spacing: Tokens.Space.sm) {
                if env.sessionUnlocked && env.trustSession {
                    Button(role: .destructive) { env.lockSession() } label: {
                        Label("Lock", systemImage: "lock.fill")
                    }
                    .help("Require Touch ID again on the next reveal or copy.")
                } else {
                    Button {
                        Task { await env.unlockForSession() }
                    } label: {
                        Label("Unlock for this session", systemImage: "lock.open.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Tokens.Palette.accent)
                    .help("One Touch ID, then reveal and copy without re-prompting until you quit or Lock.")
                }
                Button { Task { await env.testBiometric() } } label: {
                    Label("Test Touch ID", systemImage: "touchid")
                }
            }
            Stepper(
                "Re-prompt every \(Int(env.biometricSessionMinutes)) minute(s)",
                value: $env.biometricSessionMinutes,
                in: 1...60
            )
            .disabled(env.trustSession && env.sessionUnlocked)
        } header: {
            Text("Session unlock")
        } footer: {
            Text(
                "Unlock is opt-in. While unlocked, Vibe Vault owns auth: no repeated Touch ID or Keychain password sheets. When locked, re-prompt uses the interval above."
            )
        }
    }
}
