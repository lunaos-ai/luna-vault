import AppKit
import SwiftUI
import VaultCore

struct ClipboardImportSection: View {
    @EnvironmentObject var env: AppEnvironment
    let overwrite: Bool
    let onReview: ([VaultService.ImportItem]) -> Void

    @State private var phase: Phase = .idle
    @State private var previewItems: [VaultService.ImportItem] = []

    private enum Phase {
        case idle, empty, preview, failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(spacing: Tokens.Space.sm) {
                Button(action: readClipboard) {
                    Label("Read clipboard", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.Palette.accent)

                if case .preview = phase {
                    Button("Review import") { onReview(previewItems) }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.defaultAction)
                }
            }

            switch phase {
            case .idle:
                Text("Copy KEY=VALUE lines, then read your clipboard.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            case .empty:
                feedbackRow(
                    icon: "exclamationmark.circle.fill",
                    tint: Tokens.Status.warning,
                    text: "Clipboard has no dotenv-shaped lines (KEY=VALUE)."
                )
            case .preview:
                Text("Found \(previewItems.count) secret\(previewItems.count == 1 ? "" : "s"). Review before importing.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            case .failed(let msg):
                feedbackRow(icon: "xmark.circle.fill", tint: Tokens.Status.danger, text: msg)
            }
        }
        .onAppear(perform: readClipboardIfChanged)
    }

    private func readClipboard() {
        let items = ClipboardImporter.read()
        previewItems = items
        withAnimation {
            phase = items.isEmpty ? .empty : .preview
        }
        haptic(.levelChange)
    }

    private func readClipboardIfChanged() {
        if case .idle = phase, !ClipboardImporter.read().isEmpty { readClipboard() }
    }

    private func feedbackRow(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).font(.subheadline).foregroundStyle(Tokens.Text.primary)
        }
        .padding(.horizontal, Tokens.Space.sm)
        .padding(.vertical, Tokens.Space.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
    }

    private func haptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
    }
}
