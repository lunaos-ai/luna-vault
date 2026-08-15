import AppKit
import SwiftUI
import VaultCore

struct SecretVersionHistoryView: View {
    @EnvironmentObject var env: AppEnvironment
    let secret: Secret
    @State private var revisions: [SecretRevisionSummary] = []
    @State private var selectedRevision: SecretRevisionSummary?

    var body: some View {
        DisclosureGroup {
            if revisions.isEmpty {
                Text("Version history starts with the next saved change.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
                    .padding(.top, Tokens.Space.sm)
            } else {
                VStack(spacing: 0) {
                    ForEach(revisions) { revision in
                        Button {
                            selectedRevision = revision
                        } label: {
                            RevisionSummaryRow(revision: revision)
                        }
                        .buttonStyle(.plain)
                        if revision.id != revisions.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.top, Tokens.Space.sm)
            }
        } label: {
            HStack {
                Label("Version history", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                Text("\(revisions.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Tokens.Text.secondary)
            }
        }
        .padding(Tokens.Space.md)
        .background(Tokens.Surface.elevated, in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.Surface.separator.opacity(0.6), lineWidth: Tokens.Stroke.hairline)
        )
        .task(id: secret.updatedAt) { reload() }
        .sheet(item: $selectedRevision) { summary in
            SecretRevisionRestoreSheet(summary: summary) {
                reload()
            }
            .environmentObject(env)
        }
    }

    private func reload() {
        do {
            revisions = try env.service.revisionSummaries(for: secret.name)
        } catch {
            env.lastError = "\(error)"
        }
    }
}
