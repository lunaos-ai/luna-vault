import SwiftUI
import VaultCore

struct RecentActivityFeed: View {
    let events: [AuditEvent]
    var onViewAll: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                Text("Recent activity").font(.headline)
                Spacer()
                if let onViewAll {
                    Button("View all", action: onViewAll)
                        .font(.caption)
                        .buttonStyle(.link)
                }
            }
            if events.isEmpty {
                Text("No reads yet. AI agent access appears here.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
                    .padding(.vertical, Tokens.Space.md)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.prefix(6).enumerated()), id: \.element.id) { idx, event in
                        if idx > 0 { Divider().padding(.leading, 44) }
                        activityRow(event)
                    }
                }
                .luxuryCard(padding: Tokens.Space.sm)
            }
        }
    }

    private func activityRow(_ event: AuditEvent) -> some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(agentTint(event.agent).opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: actionIcon(event.action))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(agentTint(event.agent))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Tokens.Space.xs) {
                    Text(event.agent).font(.caption.weight(.semibold))
                    Text("·").foregroundStyle(Tokens.Text.tertiary)
                    Text(event.action.rawValue).font(.caption)
                }
                Text(event.secretName)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Tokens.Text.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(Tokens.Text.tertiary)
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.sm)
    }

    private func agentTint(_ agent: String) -> Color {
        if agent.contains("cursor") { return Tokens.Palette.accent }
        if agent.contains("vscode") { return Tokens.Status.info }
        if agent.contains("devin") { return Tokens.Palette.mint }
        return Tokens.Text.secondary
    }

    private func actionIcon(_ action: AuditEvent.Action) -> String {
        switch action {
        case .read: return "eye"
        case .push: return "icloud.and.arrow.up"
        case .write, .importEvent: return "square.and.pencil"
        case .delete: return "trash"
        default: return "bolt"
        }
    }
}
