import AppKit
import SwiftUI
import VaultCore

struct RecentlyDeletedSecretsSheet: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var revisions: [SecretRevisionSummary] = []
    @State private var selectedRevision: SecretRevisionSummary?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Recently Deleted", systemImage: "trash")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(Tokens.Space.lg)

            Divider()

            if revisions.isEmpty {
                ContentUnavailableView(
                    "No Deleted Secrets",
                    systemImage: "trash",
                    description: Text("Deleted secrets remain restorable while their encrypted versions are retained.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(revisions) { revision in
                    Button {
                        selectedRevision = revision
                    } label: {
                        RevisionSummaryRow(revision: revision)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 620, minHeight: 440)
        .task { reload() }
        .sheet(item: $selectedRevision) { summary in
            SecretRevisionRestoreSheet(summary: summary) {
                reload()
            }
            .environmentObject(env)
        }
    }

    private func reload() {
        do {
            revisions = try env.service.deletedSecretRevisionSummaries()
        } catch {
            env.lastError = "\(error)"
        }
    }
}
