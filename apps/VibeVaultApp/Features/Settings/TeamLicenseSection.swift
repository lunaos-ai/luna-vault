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
                        .accessibilityIdentifier("teamLicense.buyTeam")
                }
                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(Tokens.Status.danger)
                }
            }
            DisclosureGroup("How Team licensing works") {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    purchaseStep(1, "Select Buy Team to open Lemon Squeezy checkout in your browser.")
                    purchaseStep(2, "After payment, check email for a VV1 license key (usually within a few minutes).")
                    purchaseStep(3, "Paste the key above and select Activate. Verification stays offline on this Mac.")
                    purchaseStep(4, "Subscription renewals send fresh keys before expiry. Cloud Sync does not require Team.")
                }
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
                .padding(.top, Tokens.Space.xs)
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
            Text("Solo includes the full vault. Team is optional paid-seat licensing, separate from Cloud Sync.")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(env.licenseStatusLine)
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

    private func purchaseStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Text("\(number).")
                .fontWeight(.semibold)
                .frame(width: 16, alignment: .trailing)
            Text(text)
        }
    }
}
