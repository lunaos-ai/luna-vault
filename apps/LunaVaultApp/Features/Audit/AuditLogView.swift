import SwiftUI
import VaultCore

struct AuditLogView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var agentFilter = ""
    @State private var secretFilter = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            HStack {
                Text("Audit log").font(.title2.bold())
                Spacer()
                Button("Refresh") { applyFilter() }
            }
            HStack(spacing: Tokens.Space.md) {
                TextField("Filter by agent", text: $agentFilter)
                    .textFieldStyle(.roundedBorder)
                TextField("Filter by secret", text: $secretFilter)
                    .textFieldStyle(.roundedBorder)
            }

            Table(env.auditEvents) {
                TableColumn("Time") { event in
                    Text(event.timestamp.formatted(date: .abbreviated, time: .standard))
                        .font(.system(.body, design: .monospaced))
                }
                TableColumn("Agent") { event in
                    HStack {
                        Text(event.agent)
                        confidenceBadge(event.agentConfidence)
                    }
                }
                TableColumn("Secret") { event in
                    Text(event.secretName).font(.system(.body, design: .monospaced))
                }
                TableColumn("Action") { event in
                    Text(event.action.rawValue)
                }
                TableColumn("Project") { event in
                    Text(event.projectPath ?? "—")
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
        }
        .padding(Tokens.Space.xl)
        .task { applyFilter() }
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
            case .high: return Tokens.Color.success
            case .medium: return Tokens.Color.warning
            case .low: return Tokens.Color.danger
            }
        }()
        return Text(c.rawValue)
            .font(.caption2)
            .padding(.horizontal, Tokens.Space.sm)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

