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

private struct RevisionSummaryRow: View {
    let revision: SecretRevisionSummary

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: icon)
                .foregroundStyle(revision.isDeleted ? Tokens.Status.danger : Tokens.Palette.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(revision.secretName)
                    .font(.body.monospaced().weight(.medium))
                    .lineLimit(1)
                Text(revision.action.label)
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(revision.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                Text(revision.sourceHost)
                    .font(.caption2)
                    .foregroundStyle(Tokens.Text.tertiary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Tokens.Text.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, Tokens.Space.sm)
    }

    private var icon: String {
        switch revision.action {
        case .baseline: return "clock.badge.checkmark"
        case .created: return "plus.circle"
        case .updated: return "pencil.circle"
        case .rotated: return "arrow.triangle.2.circlepath"
        case .imported, .synced: return "square.and.arrow.down"
        case .restored: return "arrow.uturn.backward.circle"
        case .deleted: return "trash"
        case .mfaChanged: return "number.square"
        case .accessChanged: return "person.badge.key"
        }
    }
}

private struct SecretRevisionRestoreSheet: View {
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
