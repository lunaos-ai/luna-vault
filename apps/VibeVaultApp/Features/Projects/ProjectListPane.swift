import SwiftUI
import VaultCore

struct ProjectListPane: View {
    @EnvironmentObject var env: AppEnvironment
    let onPick: () -> Void
    let onRelocate: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if env.projects.isEmpty {
                Text("No remembered projects")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.tertiary)
                    .padding(Tokens.Space.md)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(env.projects) { project in
                            row(project)
                                .contentShape(Rectangle())
                                .onTapGesture { env.selectProject(id: project.id) }
                                .contextMenu { menus(for: project) }
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)
    }

    private var header: some View {
        HStack {
            Text("PROJECTS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Tokens.Text.secondary)
            Spacer()
            Button(action: onPick) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Add project")
            .tint(Tokens.Palette.accent)
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.sm)
    }

    private func row(_ project: ProjectRecord) -> some View {
        let selected = project.id == env.selectedProjectID
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Tokens.Space.xs) {
                Text(project.name)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .lineLimit(1)
                Spacer()
                badge(project)
            }
            Text(project.path)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Tokens.Text.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.sm)
        .background(selected ? Tokens.Palette.accent.opacity(0.12) : Color.clear)
        .foregroundStyle(Tokens.Text.primary)
    }

    @ViewBuilder
    private func badge(_ project: ProjectRecord) -> some View {
        switch project.access {
        case .missing, .notDirectory:
            Text("moved").font(.caption2.weight(.semibold)).foregroundStyle(Tokens.Status.danger)
        case .ready where project.missingCount > 0:
            Text("\(project.missingCount)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(Tokens.Status.danger)
        case .ready where project.leakCount > 0:
            Text("leak").font(.caption2.weight(.semibold)).foregroundStyle(Tokens.Status.warning)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func menus(for project: ProjectRecord) -> some View {
        Button("Scan") { env.selectProject(id: project.id) }
        if project.access != .ready {
            Button("Relocate…") { onRelocate(project.id) }
        }
        Divider()
        Button("Forget", role: .destructive) { env.forgetProject(id: project.id) }
    }
}
