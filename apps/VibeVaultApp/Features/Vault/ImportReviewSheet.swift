import SwiftUI
import VaultCore

struct ImportReviewSheet: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String
    let projectURL: URL?
    let showPrefix: Bool
    let sourceColumnTitle: String
    let stillMissing: Set<String>
    let notes: String

    @State private var prefix: String
    @State private var rows: [ImportRowState]
    @State private var showValues = false
    @State private var overwrite: Bool
    @State private var allowForAI = false
    @State private var phase: Phase = .review

    init(
        title: String = "Review import",
        subtitle: String,
        rows: [ImportRowState],
        projectURL: URL? = nil,
        showPrefix: Bool = true,
        initialPrefix: String = "",
        sourceColumnTitle: String = "Name",
        stillMissing: Set<String> = [],
        notes: String = "imported",
        overwrite: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.projectURL = projectURL
        self.showPrefix = showPrefix
        self.sourceColumnTitle = sourceColumnTitle
        self.stillMissing = stillMissing
        self.notes = notes
        _prefix = State(initialValue: initialPrefix)
        _rows = State(initialValue: rows)
        _overwrite = State(initialValue: overwrite)
    }

    var body: some View {
        Group {
            switch phase {
            case .review:
                reviewContent
            case .success(let count, let vaultNames, let workerNames, let highlight):
                ImportSuccessStep(
                    importedCount: count,
                    subtitle: subtitle,
                    highlightName: highlight,
                    projectURL: projectURL,
                    vaultNames: vaultNames,
                    workerNames: workerNames,
                    onDone: { dismiss() }
                )
            }
        }
        .padding(Tokens.Space.xl)
        .frame(minWidth: 620, minHeight: phase.minHeight)
        .onAppear {
            if showPrefix, let url = projectURL, prefix.isEmpty {
                prefix = env.projectPrefix(for: url)
            }
        }
    }

    private var reviewContent: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            header
            ImportReviewControls(
                prefix: $prefix,
                showValues: $showValues,
                overwrite: $overwrite,
                allowForAI: $allowForAI,
                showPrefix: showPrefix,
                selectedCount: rows.filter(\.enabled).count,
                exampleVaultName: rows.first.map { $0.vaultName(prefix: prefix) },
                onPrefixChange: { v in
                    if let url = projectURL { env.saveProjectPrefix(v, for: url) }
                }
            )
            if rows.isEmpty { emptyState } else {
                ImportReviewTable(
                    rows: $rows,
                    prefix: prefix,
                    sourceColumnTitle: sourceColumnTitle,
                    showValues: $showValues
                )
            }
            if !stillMissing.isEmpty { missingNote }
            footer
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(title).font(.system(size: 22, weight: .semibold))
            Text(subtitle)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Tokens.Text.secondary)
                .lineLimit(2)
        }
    }

    private var emptyState: some View {
        Text("No secrets to import.")
            .foregroundStyle(Tokens.Text.secondary)
            .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var missingNote: some View {
        Text("No dotenv value for \(stillMissing.count) secret\(stillMissing.count == 1 ? "" : "s"). Add manually after import.")
            .font(.caption)
            .foregroundStyle(Tokens.Status.warning)
    }

    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            Spacer()
            Button("Import \(rows.filter(\.enabled).count) secrets") { importSelected() }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.Palette.accent)
                .disabled(rows.filter(\.enabled).isEmpty)
                .keyboardShortcut(.defaultAction)
        }
    }

    private func importSelected() {
        let selected = rows.filter(\.enabled)
        let items = selected.map { row in
            VaultService.ImportItem(
                name: row.vaultName(prefix: prefix),
                value: row.value,
                notes: row.notes ?? notes
            )
        }
        do {
            let res: VaultService.ImportResult
            if let url = projectURL {
                res = try env.importReviewed(items: items, overwrite: overwrite, projectURL: url)
            } else {
                res = try env.importItems(items, overwrite: overwrite)
                env.importStatus = "Imported \(res.imported.count) · updated \(res.updated.count) · skipped \(res.skipped.count)"
            }
            let count = res.imported.count + res.updated.count
            let vaultNames = Set(items.map(\.name))
            let workerNames = Set(selected.map(\.sourceName))
            let highlight = items.first?.name
            if allowForAI {
                Task { await env.allowMCPAccess(for: vaultNames) }
            }
            phase = .success(count: count, vaultNames: vaultNames, workerNames: workerNames, highlight: highlight)
        } catch {
            env.importStatus = "error: \(error)"
        }
    }
}

private enum Phase {
    case review
    case success(count: Int, vaultNames: Set<String>, workerNames: Set<String>, highlight: String?)

    var minHeight: CGFloat {
        switch self {
        case .review: return 460
        case .success: return 300
        }
    }
}
