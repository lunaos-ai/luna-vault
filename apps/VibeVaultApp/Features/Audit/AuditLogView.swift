import SwiftUI
import VaultCore

struct AuditLogView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var agentFilter = ""
    @State private var secretFilter = ""
    @State private var scope: Scope = .all

    enum Scope: String, CaseIterable, Identifiable {
        case all = "All", granted = "Allowed", denied = "Denied"
        var id: String { rawValue }
        var grantedFilter: Bool? {
            switch self { case .all: nil; case .granted: true; case .denied: false }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                filterCard
                tableCard
            }
            .padding(Tokens.Space.xxl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(LiquidBackdrop())
        .navigationTitle("Access Log")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { applyFilter() } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Reload access events")
            }
        }
        .task { applyFilter() }
        .onChange(of: agentFilter) { _, _ in applyFilter() }
        .onChange(of: secretFilter) { _, _ in applyFilter() }
        .onChange(of: scope) { _, _ in applyFilter() }
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                Text("Filters").sectionLabel()
                Spacer()
                Text("\(env.auditEvents.count) event\(env.auditEvents.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            HStack(spacing: Tokens.Space.sm) {
                field(prompt: "Filter by agent", text: $agentFilter, icon: "person.crop.square")
                field(prompt: "Filter by secret", text: $secretFilter, icon: "key")
                Spacer()
            }
            Picker("Outcome", selection: $scope) {
                ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 280)
        }
        .glassCard()
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
        .background(Tokens.Surface.elevated.opacity(0.6), in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .strokeBorder(Tokens.Glass.edge, lineWidth: Tokens.Stroke.hairline)
        )
        .frame(maxWidth: 220)
    }

    @ViewBuilder
    private var tableCard: some View {
        if env.auditEvents.isEmpty && agentFilter.isEmpty && secretFilter.isEmpty {
            ContentUnavailableView(
                "No audit events yet",
                systemImage: "list.bullet.rectangle",
                description: Text("Every secret read, write, and rotation will appear here.")
            )
            .frame(maxWidth: .infinity)
            .padding(Tokens.Space.xxl)
            .glassPanel()
        } else {
            table
                .frame(minHeight: 320)
                .glassPanel()
        }
    }

    private var table: some View {
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
            TableColumn("Outcome") { event in
                outcomeBadge(event)
            }
            .width(min: 80, ideal: 96)
            TableColumn("Project") { event in
                Text(event.projectPath ?? "·")
                    .lineLimit(1)
                    .truncationMode(.head)
                    .foregroundStyle(Tokens.Text.secondary)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func applyFilter() {
        var f = AuditFilter(limit: 500)
        if !agentFilter.isEmpty { f.agent = agentFilter }
        if !secretFilter.isEmpty { f.secretName = secretFilter }
        f.granted = scope.grantedFilter
        env.refreshAudit(filter: f)
    }

    private func outcomeBadge(_ event: AuditEvent) -> some View {
        // Only reads are gated by Touch ID; writes/imports are always "allowed".
        let denied = !event.granted
        let tint = denied ? Tokens.Status.danger : Tokens.Status.success
        let label = denied ? "Denied" : "Allowed"
        return Label(label, systemImage: denied ? "xmark.shield.fill" : "checkmark.shield.fill")
            .labelStyle(.titleAndIcon)
            .glassChip(tint)
    }

    private func confidenceBadge(_ c: AgentConfidence) -> some View {
        let tint: Color = {
            switch c {
            case .high: return Tokens.Status.success
            case .medium: return Tokens.Status.warning
            case .low: return Tokens.Status.danger
            }
        }()
        return Text(c.rawValue).glassChip(tint)
    }
}
