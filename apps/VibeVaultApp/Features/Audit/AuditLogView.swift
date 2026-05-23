import SwiftUI
import VaultCore

struct AuditLogView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var agentFilter = ""
    @State private var secretFilter = ""

    var body: some View {
        VStack(spacing: 0) {
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
                        Text(event.projectPath ?? "—")
                            .lineLimit(1)
                            .truncationMode(.head)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .searchable(text: $secretFilter, prompt: "Filter by secret name")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                TextField("Agent", text: $agentFilter, prompt: Text("Agent"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    applyFilter()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .navigationTitle("Audit Log")
        .task { applyFilter() }
        .onChange(of: agentFilter) { _, _ in applyFilter() }
        .onChange(of: secretFilter) { _, _ in applyFilter() }
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
            case .high: return .green
            case .medium: return .orange
            case .low: return .red
            }
        }()
        return Text(c.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}
