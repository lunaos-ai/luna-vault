import AppKit
import SwiftUI
import VaultCore

struct SecretRevisionRestoreSheet: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    let summary: SecretRevisionSummary
    let onRestored: () -> Void
    @State private var revision: SecretRevision?
    @State private var showValue = false
    @State private var confirmRestore = false
    @State private var isRestoring = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            HStack {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text(summary.secretName)
                        .font(.title2.monospaced().weight(.semibold))
                    Text("\(summary.action.label) · \(summary.capturedAt.formatted(date: .abbreviated, time: .standard))")
                        .foregroundStyle(Tokens.Text.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
            }

            Divider()

            if let revision {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    Text("Saved value")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Tokens.Text.secondary)
                    HStack(spacing: Tokens.Space.sm) {
                        Text(showValue ? revision.secret.value : revision.secret.maskedValue)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(2)
                        Spacer()
                        Button {
                            showValue.toggle()
                        } label: {
                            Image(systemName: showValue ? "eye.slash" : "eye")
                        }
                        .help(showValue ? "Hide saved value" : "Show saved value")
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(revision.secret.value, forType: .string)
                            env.showToast("Copied saved value")
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .help("Copy saved value")
                    }
                    .padding(Tokens.Space.md)
                    .deepInset()
                }

                Grid(alignment: .leading, horizontalSpacing: Tokens.Space.xl, verticalSpacing: Tokens.Space.sm) {
                    metadataRow("Source Mac", revision.sourceHost)
                    metadataRow("Created", revision.secret.createdAt.formatted(date: .abbreviated, time: .shortened))
                    metadataRow("Saved", revision.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    metadataRow("MFA", revision.secret.hasTOTP ? "Included" : "None")
                    metadataRow("AI access", revision.secret.mcpAllowed ? "Allowed" : "Blocked")
                }

                Spacer()

                HStack {
                    Text("Restoring creates a new version and preserves this history.")
                        .font(.caption)
                        .foregroundStyle(Tokens.Text.secondary)
                    Spacer()
                    Button {
                        confirmRestore = true
                    } label: {
                        Label("Restore this version", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRestoring)
                }
            } else {
                ProgressView("Unlocking saved version...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(Tokens.Space.xl)
        .frame(width: 640, height: 470)
        .task { await loadRevision() }
        .confirmationDialog(
            "Restore this version of \(summary.secretName)?",
            isPresented: $confirmRestore,
            titleVisibility: .visible
        ) {
            Button("Restore") { Task { await restore() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current value remains available in version history.")
        }
    }

    @ViewBuilder
    private func metadataRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(Tokens.Text.secondary)
            Text(value).textSelection(.enabled)
        }
    }

    private func loadRevision() async {
        do {
            revision = try await env.service.readRevision(
                id: summary.id,
                name: summary.secretName,
                reason: "Preview an earlier version of \(summary.secretName)"
            )
        } catch {
            env.lastError = "\(error)"
            env.showToast("Could not unlock saved version", feedback: .caution)
            dismiss()
        }
    }

    private func restore() async {
        isRestoring = true
        do {
            _ = try await env.service.restoreRevision(id: summary.id, name: summary.secretName)
            env.refresh()
            onRestored()
            env.showToast("Restored \(summary.secretName)")
            dismiss()
        } catch {
            env.lastError = "\(error)"
            env.showToast("Could not restore version", feedback: .caution)
            isRestoring = false
        }
    }
}
