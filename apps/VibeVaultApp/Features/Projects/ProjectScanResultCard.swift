import SwiftUI
import VaultCore

struct ProjectScanResultCard: View {
    let result: ScanResult
    let filter: ProjectScannerView.ResultFilter
    let projectURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showMissing && !result.missing.isEmpty {
                section(
                    title: "Missing in vault",
                    count: result.missing.count,
                    items: Array(result.missing).sorted(),
                    tint: Tokens.Status.danger,
                    glyph: "exclamationmark.triangle.fill",
                    showProvenance: true
                )
            }
            if showExtra && !result.extra.isEmpty {
                if showMissing && !result.missing.isEmpty {
                    Divider().background(Tokens.Surface.separator)
                }
                section(
                    title: "Extra in vault",
                    count: result.extra.count,
                    items: Array(result.extra).sorted(),
                    tint: Tokens.Status.warning,
                    glyph: "questionmark.circle.fill",
                    showProvenance: false
                )
            }
            if showAll && !okList.isEmpty {
                if !result.missing.isEmpty || !result.extra.isEmpty {
                    Divider().background(Tokens.Surface.separator)
                }
                section(
                    title: "Required and present",
                    count: okList.count,
                    items: okList,
                    tint: Tokens.Status.success,
                    glyph: "checkmark.circle.fill",
                    showProvenance: true
                )
            }
            if isEmpty { emptyState }
        }
        .glassPanel(radius: Tokens.Radius.lg)
        .glassHover()
    }

    private var showMissing: Bool { filter == .all || filter == .missing }
    private var showExtra: Bool { filter == .all || filter == .extras }
    private var showAll: Bool { filter == .all }

    private var okList: [String] {
        result.required.subtracting(result.missing).sorted()
    }

    private var isEmpty: Bool {
        switch filter {
        case .missing: return result.missing.isEmpty
        case .extras: return result.extra.isEmpty
        case .all: return result.required.isEmpty && result.extra.isEmpty
        }
    }

    private var emptyState: some View {
        HStack {
            Text(filter == .missing ? "No missing secrets" :
                 filter == .extras ? "No extras in vault" :
                 "No required secrets detected")
                .foregroundStyle(Tokens.Text.secondary)
                .font(.subheadline)
            Spacer()
        }
        .padding(Tokens.Space.lg)
    }

    @ViewBuilder
    private func section(
        title: String, count: Int, items: [String],
        tint: Color, glyph: String, showProvenance: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: glyph)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Tokens.Text.secondary)
                Spacer()
                Text("\(count)")
                    .monospacedDigit()
                    .glassChip(tint)
            }
            .padding(.horizontal, Tokens.Space.md)
            .padding(.top, Tokens.Space.md)
            .padding(.bottom, Tokens.Space.sm)

            ForEach(Array(items.enumerated()), id: \.element) { idx, name in
                row(name: name, showProvenance: showProvenance)
                if idx < items.count - 1 {
                    Divider().padding(.leading, Tokens.Space.md)
                }
            }
            .padding(.bottom, Tokens.Space.xs)
        }
    }

    private func row(name: String, showProvenance: Bool) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            Text(name)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Tokens.Text.primary)
            if showProvenance, let src = sources(for: name) {
                Text("·").foregroundStyle(Tokens.Text.tertiary)
                Text(src)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(name, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Tokens.Text.tertiary)
            .help("Copy name")
            .accessibilityLabel("Copy \(name)")
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.sm)
        .contentShape(Rectangle())
    }

    private func sources(for name: String) -> String? {
        let hits = result.sources.compactMap { (file, names) -> String? in
            names.contains(name) ? file : nil
        }
        guard !hits.isEmpty else { return nil }
        if hits.count == 1 { return hits[0] }
        return "\(hits[0]) +\(hits.count - 1)"
    }
}
