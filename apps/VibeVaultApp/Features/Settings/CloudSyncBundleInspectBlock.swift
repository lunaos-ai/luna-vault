import SwiftUI
import VaultCore

struct CloudSyncBundleInspectBlock: View {
    @EnvironmentObject var env: AppEnvironment
    let info: CloudSyncBundleInfo?
    let errorText: String?

    var body: some View {
        if info != nil || errorText != nil {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                if let info {
                    LabeledContent("Source Mac", value: info.sourceHost)
                    LabeledContent(
                        "Created",
                        value: info.createdAt.formatted(date: .abbreviated, time: .shortened)
                    )
                    LabeledContent(
                        "Recovery protection",
                        value: info.hasRecoveryProtection ? "Present" : "None"
                    )
                    if let fingerprint = info.recoveryFingerprint {
                        LabeledContent("Required recovery key", value: fingerprint)
                    }
                    LabeledContent(
                        "Installed key",
                        value: CloudSyncRecoveryAccess.matchLabel(
                            info: info,
                            keys: env.cachedRecoveryKeys
                        )
                    )
                    if info.isLegacyRecovery {
                        Text(CloudSyncRecoveryCopy.legacyIdentityUnavailable)
                            .foregroundStyle(Tokens.Status.warning)
                    }
                }
                if let errorText, !errorText.isEmpty {
                    Text(errorText)
                        .foregroundStyle(Tokens.Status.danger)
                        .textSelection(.enabled)
                        .accessibilityLabel("Recovery preview error")
                        .accessibilityValue(errorText)
                }
            }
            .font(.caption)
            .textSelection(.enabled)
        }
    }
}
