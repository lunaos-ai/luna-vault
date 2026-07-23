import SwiftUI

struct VaultSearchField: View {
    @Binding var search: String
    var isFocused: FocusState<Bool>.Binding

    private var active: Bool {
        isFocused.wrappedValue || !search.isEmpty
    }

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? Tokens.Palette.accent : Tokens.Text.secondary)
                .frame(width: 18, height: 18)
            TextField("Search secrets", text: $search)
                .textFieldStyle(.plain)
                .focused(isFocused)
            if !search.isEmpty {
                Button {
                    search = ""
                    isFocused.wrappedValue = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Tokens.Text.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, Tokens.Space.md)
        .frame(height: 38)
        .background(
            active ? Tokens.Palette.accent.opacity(0.12) : Tokens.Surface.elevated.opacity(0.75),
            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .strokeBorder(
                    active ? Tokens.Palette.accent.opacity(0.8) : Tokens.Surface.separator.opacity(0.55),
                    lineWidth: active ? Tokens.Stroke.thin : Tokens.Stroke.hairline
                )
        )
    }
}

struct VaultListOptionsBar: View {
    @Binding var sort: VaultListSort
    @Binding var grouping: VaultListGrouping

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            Picker(selection: $sort) {
                ForEach(VaultListSort.allCases) { option in
                    Text(option.label).tag(option)
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .pickerStyle(.menu)
            .help("Sort secrets")

            Picker(selection: $grouping) {
                ForEach(VaultListGrouping.allCases) { option in
                    Text(option.label).tag(option)
                }
            } label: {
                Label("Group", systemImage: "rectangle.3.group")
            }
            .pickerStyle(.menu)
            .help("Group secrets")
            Spacer(minLength: 0)
        }
        .controlSize(.small)
    }
}

struct VaultListSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            Text(title)
            Text("\(count)")
                .foregroundStyle(Tokens.Text.tertiary)
        }
        .sectionLabel()
        .padding(.top, Tokens.Space.xs)
    }
}
