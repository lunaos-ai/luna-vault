import SwiftUI
import VaultCore

struct AuditLogView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var agentFilter = ""
    @State private var secretFilter = ""

    var body: some View {
        VStack(spacing: 0) {
            auditHero
            filterBar
            Divider()
            table
        }
        .background(PremiumBackdrop())
        .navigationTitle("Audit Log")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { applyFilter() } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Reload audit events")
            }
        }
        .task { applyFilter() }
        .onChange(of: agentFilter) { _, _ in applyFilter() }
        .onChange(of: secretFilter) { _, _ in applyFilter() }
    }

    private var auditHero: some View {
        HStack(spacing: Tokens.Space.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Agent audit trail")
                    .font(.title2.weight(.semibold))
                    .tracking(-0.3)
                Text("Every read, write, and push tagged by agent.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            Spacer()
            Text("\(env.auditEvents.count)")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Palette.accent)
            Text("events")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
        }
        .padding(.horizontal, Tokens.Space.xxl)
        .padding(.vertical, Tokens.Space.lg)
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(spacing: Tokens.Space.sm) {
                agentChip("All", value: "")
                agentChip("Cursor", value: "cursor")
                agentChip("Claude", value: "claude")
                agentChip("Devin", value: "devin")
                agentChip("VS Code", value: "vscode")
                Spacer()
            }
            HStack(spacing: Tokens.Space.sm) {
                field(prompt: "Filter by agent", text: $agentFilter, icon: "person.crop.square")
                field(prompt: "Filter by secret", text: $secretFilter, icon: "key")
                Spacer()
                Text("\(env.auditEvents.count) event\(env.auditEvents.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func agentChip(_ label: String, value: String) -> some View {
        let selected = agentFilter.lowercased() == value.lowercased()
            || (value.isEmpty && agentFilter.isEmpty)
        return Button {
            agentFilter = value
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, Tokens.Space.sm)
                .padding(.vertical, Tokens.Space.xs)
                .background(
                    (selected ? Tokens.Palette.accent : Tokens.Text.tertiary).opacity(selected ? 0.15 : 0.08),
                    in: Capsule()
                )
                .foregroundStyle(selected ? Tokens.Palette.accent : Tokens.Text.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter agent \(label)")
    }

    private func field(prompt: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.Text.tertiary)
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, Tokens.Space.sm)
        .padding(.vertical, 5)
        .background(Tokens.Surface.elevated, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .strokeBorder(Tokens.Surface.separator.opacity(0.6), lineWidth: Tokens.Stroke.hairline)
        )
        .frame(maxWidth: 220)
    }

    @ViewBuilder
    private var table: some View {
        if env.auditEvents.isEmpty && agentFilter.isEmpty && secretFilter.isEmpty {
            ContentUnavailableView(
                "No audit events yet",
                systemImage: "list.bullet.rectangle",
                description: Text("Every secret read, write, and rotation will appear here.")
            )
        } else {
            Table(env.auditEvents) {
                TableColumn("Time") { event in
                    Text(event.timestamp.formatted(date: .abbreviated, time: .standard))
                        .font(.system(.body, design: .monospaced))
                }
                .width(min: 160, ideal: 180)
                TableColumn("Agent") { event in
                    HStack(spacing: 6) {
                        Text(event.agent)
                        confidenceBadge(event.agentConfidence)
                    }
                }
                .width(min: 140, ideal: 160)
                TableColumn("Secret") { event in
                    Text(event.secretName).font(.system(.body, design: .monospaced))
                }
                .width(min: 160, ideal: 200)
                TableColumn("Action") { event in
                    Text(event.action.rawValue.capitalized)
                }
                .width(min: 70, ideal: 90)
                TableColumn("Project") { event in
                    Text(event.projectPath ?? "·")
                        .lineLimit(1)
                        .truncationMode(.head)
                        .foregroundStyle(Tokens.Text.secondary)
                }
            }
        }
    }

    private func applyFilter() {
        var f = AuditFilter(limit: 500)
        if !agentFilter.isEmpty { f.agent = agentFilter }
        if !secretFilter.isEmpty { f.secretName = secretFilter }
        env.refreshAudit(filter: f)
    }

    private func confidenceBadge(_ c: AgentConfidence) -> some View {
        let tint: Color = {
            switch c {
            case .high: return Tokens.Status.success
            case .medium: return Tokens.Status.warning
            case .low: return Tokens.Status.danger
            }
        }()
        return Text(c.rawValue)
            .font(.caption2.weight(.semibold))
            .tintedChip(tint)
    }
}
