import SwiftUI
import VaultCore

struct RevisionSummaryRow: View {
    let revision: SecretRevisionSummary

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(revision.action.label)
                    .font(.headline)
                Text(revision.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            Spacer()
            Text(revision.sourceHost)
                .font(.caption.monospaced())
                .foregroundStyle(Tokens.Text.secondary)
        }
        .padding(.vertical, Tokens.Space.sm)
    }
}
