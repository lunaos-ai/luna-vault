import SwiftUI

/// Unlock once for a bounded window shared by all local VibeVault clients.
struct SessionTrustSection: View {
    @EnvironmentObject var env: AppEnvironment

    var body: some View {
        Section {
            LabeledContent("Status", value: env.biometricStatus)
            Picker("Unlock duration", selection: $env.biometricSessionMinutes) {
                Text("5 minutes").tag(5.0)
                Text("15 minutes").tag(15.0)
                Text("30 minutes").tag(30.0)
                Text("1 hour").tag(60.0)
                Text("2 hours").tag(120.0)
                Text("4 hours").tag(240.0)
                Text("8 hours").tag(480.0)
            }
            .disabled(env.sessionUnlocked)
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
                        Label("Unlock VibeVault", systemImage: "lock.open.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Tokens.Palette.accent)
                    .help("One approval opens app and CLI access for the selected time.")
                }
                Button { Task { await env.testBiometric() } } label: {
                    Label("Test Touch ID", systemImage: "touchid")
                }
            }
        } header: {
            Text("Shared unlock")
        } footer: {
            Text(
                "One approval suppresses repeated VibeVault authentication in the app and CLI until expiry or Lock. AI-agent allowlists remain enforced. macOS can still request one-time Keychain authorization after an app update."
            )
        }
    }
}
