import SwiftUI
import VaultCore

struct AISkillSection: View {
    @State private var statuses: [AgentSkillTarget: AgentSkillStatus] = [:]
    @State private var outdated: [AgentSkillTarget: Bool] = [:]
    @State private var message: String?

    private var anyOutdated: Bool {
        outdated.values.contains(true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Agent skill").font(.subheadline.weight(.semibold))
                    Text(anyOutdated
                         ? "Update available (v\(AgentSkillContent.version))"
                         : "Teaches Cursor, Claude, and Devin how to use Vibe Vault.")
                        .font(.caption)
                        .foregroundStyle(anyOutdated ? Tokens.Status.warning : Tokens.Text.secondary)
                }
                Spacer()
                Button(anyOutdated ? "Update skill" : "Install skill") { installAll() }
                    .buttonStyle(.borderedProminent)
                    .tint(Tokens.Palette.accent)
            }
            ForEach(AgentSkillTarget.allCases, id: \.self) { target in
                HStack {
                    Text(target.displayName).font(.caption)
                    Spacer()
                    Text(statusLabel(for: target))
                        .font(.caption2)
                        .foregroundStyle(statusColor(for: target))
                }
            }
            if let message {
                Text(message).font(.caption).foregroundStyle(Tokens.Text.secondary)
            }
        }
        .padding(Tokens.Space.lg)
        .cardSurface()
        .task { refresh() }
    }

    private func statusLabel(for target: AgentSkillTarget) -> String {
        if statuses[target]?.installed != true { return "Missing" }
        if outdated[target] == true { return "Outdated" }
        return "Installed"
    }

    private func statusColor(for target: AgentSkillTarget) -> Color {
        if statuses[target]?.installed != true { return Tokens.Text.tertiary }
        if outdated[target] == true { return Tokens.Status.warning }
        return Tokens.Status.success
    }

    private func refresh() {
        var out: [AgentSkillTarget: AgentSkillStatus] = [:]
        var old: [AgentSkillTarget: Bool] = [:]
        for t in AgentSkillTarget.allCases {
            out[t] = AgentSkillInstaller.status(of: t)
            old[t] = AgentSkillInstaller.isOutdated(target: t)
        }
        statuses = out
        outdated = old
    }

    private func installAll() {
        do {
            try AgentSkillInstaller.installAll(content: AgentSkillInstaller.bundledSkillContent())
            message = "Skill v\(AgentSkillContent.version) installed."
            refresh()
        } catch {
            message = "\(error)"
        }
    }
}
