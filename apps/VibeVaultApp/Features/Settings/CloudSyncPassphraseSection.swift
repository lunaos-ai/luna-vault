import SwiftUI

struct CloudSyncPassphraseSection: View {
    @Binding var passphrase: String
    @Binding var confirmation: String
    @Binding var importPolicy: AppCloudSyncImportPolicy

    private var hasValidPassphraseLength: Bool {
        passphrase.count >= 12
    }

    private var passphrasesMatch: Bool {
        !confirmation.isEmpty && passphrase == confirmation
    }

    var body: some View {
        SecureField("Sync passphrase", text: $passphrase)
        SecureField("Confirm passphrase", text: $confirmation)
        HStack(spacing: Tokens.Space.lg) {
            passphraseRequirement("12+ characters", satisfied: hasValidPassphraseLength)
            passphraseRequirement("Passphrases match", satisfied: passphrasesMatch)
        }
        .font(.caption)

        Picker("Existing names on import", selection: $importPolicy) {
            ForEach(AppCloudSyncImportPolicy.allCases) { policy in
                Text(policy.label).tag(policy)
            }
        }
        .pickerStyle(.segmented)
    }

    private func passphraseRequirement(_ label: String, satisfied: Bool) -> some View {
        Label(label, systemImage: satisfied ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(satisfied ? Tokens.Status.success : Tokens.Text.secondary)
    }
}
