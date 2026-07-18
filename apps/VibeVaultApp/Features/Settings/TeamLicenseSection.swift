import SwiftUI
import VaultCore

struct TeamLicenseSection: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var keyDraft = ""
    @State private var errorText: String?
    @State private var checkoutDraft = ""

    var body: some View {
        Section {
            statusRow
            if env.isTeamLicensed {
                Button("Remove license", role: .destructive) {
                    env.deactivateLicense()
                    keyDraft = ""
                }
            } else {
                TextField("License key", text: $keyDraft, prompt: Text("VV1.…"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                HStack {
                    Button("Activate") { activate() }
                        .buttonStyle(.borderedProminent)
                        .tint(Tokens.Palette.accent)
                        .disabled(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Buy Team") { env.openTeamCheckout() }
                }
                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(Tokens.Status.danger)
                }
            }
            DisclosureGroup("Checkout URL") {
                TextField("Lemon Squeezy checkout", text: $checkoutDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                Button("Save checkout URL") {
                    env.setLemonCheckoutURL(checkoutDraft.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        } header: {
            Text("Team license")
        } footer: {
            Text("Solo stays free. Team unlocks with an offline key from Lemon Squeezy. Verification never phones home.")
        }
        .onAppear {
            checkoutDraft = LemonSqueezyConfig.checkoutURL(prefs: env.prefs).absoluteString
        }
    }

    private var statusRow: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: env.isTeamLicensed ? "checkmark.seal.fill" : "person")
                .foregroundStyle(env.isTeamLicensed ? Tokens.Status.success : Tokens.Text.secondary)
            Text(env.licenseStatusLine)
                .foregroundStyle(Tokens.Text.secondary)
        }
    }

    private func activate() {
        errorText = nil
        do {
            try env.activateLicense(keyDraft)
            keyDraft = ""
        } catch {
            errorText = (error as? LicenseError)?.description ?? error.localizedDescription
        }
    }
}
