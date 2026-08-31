import SwiftUI
import VaultCore

struct CloudSyncRecoveryKeyRow: View {
    let summary: RecoveryKeySummary
    let selectedBundleID: String?
    let onShow: () -> Void
    let onMakeActive: () -> Void
    let onStopActive: () -> Void
    let onRemove: () -> Void

    private var matchesSelected: Bool? {
        guard let selectedBundleID else { return nil }
        return selectedBundleID == summary.identifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack {
                Text(summary.fingerprint)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .textSelection(.enabled)
                    .accessibilityLabel("Recovery key fingerprint \(summary.fingerprint)")
                Spacer()
                Text(summary.isActive ? "Active" : "Retained")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(summary.isActive ? Tokens.Status.success : Tokens.Text.secondary)
            }
            Text(dateLine)
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
            if let matchesSelected {
                Text(matchesSelected ? "Matches this backup" : "Does not match this backup")
                    .font(.caption)
                    .foregroundStyle(matchesSelected ? Tokens.Status.success : Tokens.Text.secondary)
            }
            HStack {
                Button("Show or export key", action: onShow)
                    .accessibilityLabel("Show or export key \(summary.fingerprint)")
                if summary.isActive {
                    Button("Stop using for new backups", action: onStopActive)
                } else {
                    Button("Make active for new backups", action: onMakeActive)
                    Button("Remove retained key", role: .destructive, action: onRemove)
                }
            }
        }
        .padding(.vertical, Tokens.Space.xs)
        .accessibilityElement(children: .contain)
    }

    private var dateLine: String {
        let created = summary.createdAt.formatted(date: .abbreviated, time: .omitted)
        if let imported = summary.importedAt {
            return "Created \(created) · Imported \(imported.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Created \(created)"
    }
}
