import SwiftUI
import VaultCore

/// Spotlight-style ⌘K palette: searches secrets (name, notes, value) and jumps
/// to any sidebar destination. Keyboard-driven, dismisses on Esc or backdrop tap.
struct CommandPaletteView: View {
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject var nav: Navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var query = ""
    @State private var selected = 0
    @FocusState private var fieldFocused: Bool

    enum Hit: Identifiable {
        case navigate(MainWindow.SidebarItem)
        case secret(SecretMatch)
        var id: String {
            switch self {
            case .navigate(let item): return "nav-\(item.rawValue)"
            case .secret(let match): return "sec-\(match.secret.name)"
            }
        }
    }

    private var hits: [Hit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let destinations = MainWindow.SidebarItem.allCases
        guard !q.isEmpty else { return destinations.map(Hit.navigate) }
        let nav = destinations
            .filter { $0.label.localizedCaseInsensitiveContains(q) }
            .map(Hit.navigate)
        let secrets = SecretSearch.rank(env.secrets, query: q, limit: 12).map(Hit.secret)
        return nav + secrets
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { nav.paletteOpen = false }
            palette
                .padding(.top, 96)
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
        .onAppear { fieldFocused = true }
        .onChange(of: query) { _, _ in selected = 0 }
    }

    private var palette: some View {
        VStack(spacing: 0) {
            searchField
            if hits.isEmpty {
                emptyRow
            } else {
                resultsList
            }
        }
        .frame(width: 560)
        .glassPanel(radius: Tokens.Radius.lg, elevation: .lifted)
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.return) { activateSelected(); return .handled }
        .onKeyPress(.escape) { nav.paletteOpen = false; return .handled }
    }

    private var searchField: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Tokens.Text.tertiary)
            TextField("Search secrets and screens", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($fieldFocused)
                .onSubmit { activateSelected() }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Surface.separator.opacity(0.5)).frame(height: Tokens.Stroke.hairline)
        }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(hits.enumerated()), id: \.element.id) { index, hit in
                        PaletteRow(hit: hit, active: index == selected)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture { activate(hit) }
                            .onHover { if $0 { selected = index } }
                    }
                }
                .padding(Tokens.Space.sm)
            }
            .frame(maxHeight: 320)
            .onChange(of: selected) { _, new in
                withAnimation(reduceMotion ? nil : Tokens.Motion.snappy) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    private var emptyRow: some View {
        Text("No matches")
            .font(.system(size: 13))
            .foregroundStyle(Tokens.Text.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Space.lg)
    }

    private func move(_ delta: Int) {
        guard !hits.isEmpty else { return }
        selected = min(max(0, selected + delta), hits.count - 1)
    }

    private func activateSelected() {
        guard hits.indices.contains(selected) else { return }
        activate(hits[selected])
    }

    private func activate(_ hit: Hit) {
        switch hit {
        case .navigate(let item): nav.go(item)
        case .secret(let match): nav.reveal(secret: match.secret.id)
        }
    }
}

/// A single palette result row: leading glyph, title, and a reason subtitle.
private struct PaletteRow: View {
    let hit: CommandPaletteView.Hit
    let active: Bool

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: glyph)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(active ? Tokens.Palette.accent : Tokens.Text.tertiary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(titleFont).lineLimit(1)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(Tokens.Text.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .fill(active ? Tokens.Palette.accent.opacity(0.14) : .clear)
        )
    }

    private var glyph: String {
        switch hit {
        case .navigate(let item): return item.systemImage
        case .secret: return "key.fill"
        }
    }

    private var title: String {
        switch hit {
        case .navigate(let item): return item.label
        case .secret(let match): return match.secret.name
        }
    }

    private var titleFont: Font {
        switch hit {
        case .navigate: return .system(size: 13, weight: .medium)
        case .secret: return .system(size: 13, design: .monospaced).weight(.medium)
        }
    }

    private var subtitle: String {
        switch hit {
        case .navigate: return "Go to screen"
        case .secret(let match):
            switch match.field {
            case .name: return "Secret"
            case .notes: return "Matches notes"
            case .value: return "Matches value"
            }
        }
    }
}
