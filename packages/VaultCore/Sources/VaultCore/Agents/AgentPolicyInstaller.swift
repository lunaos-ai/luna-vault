import Foundation

public enum AgentPolicyTarget: String, CaseIterable, Sendable {
    case codex
    case claude
    case gemini
    case cursor

    public var displayName: String {
        switch self {
        case .codex: return "ChatGPT Codex"
        case .claude: return "Claude Code"
        case .gemini: return "Gemini CLI"
        case .cursor: return "Cursor"
        }
    }

    public func policyURL(projectURL: URL) -> URL {
        switch self {
        case .codex:
            return projectURL.appendingPathComponent(AgentsMarkdownGenerator.fileName)
        case .claude:
            return projectURL.appendingPathComponent("CLAUDE.md")
        case .gemini:
            return projectURL.appendingPathComponent("GEMINI.md")
        case .cursor:
            return CursorRulesInstaller.rulesURL(projectURL: projectURL)
        }
    }
}

public struct AgentPolicyInstallResult: Equatable, Sendable {
    public let target: AgentPolicyTarget
    public let path: String
    public let installed: Bool
}

public struct AgentPolicyStatus: Equatable, Sendable {
    public let target: AgentPolicyTarget
    public let path: String
    public let installed: Bool
    public let needsUpdate: Bool
}

public enum AgentPolicyInstaller {
    public static func install(
        projectURL: URL,
        target: AgentPolicyTarget,
        scan: ScanResult?
    ) throws -> AgentPolicyInstallResult {
        if target == .cursor {
            try CursorRulesInstaller.install(projectURL: projectURL)
            return result(target, projectURL)
        }
        if target == .codex {
            _ = try AgentsMarkdownGenerator.install(projectURL: projectURL, scan: scan)
            return result(target, projectURL)
        }
        let url = target.policyURL(projectURL: projectURL)
        let body = policyBody(target: target, projectName: projectURL.lastPathComponent)
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let stripped = AgentsMarkdownGenerator.stripMarkedSection(existing)
        try append(body, to: stripped).write(to: url, atomically: true, encoding: .utf8)
        return result(target, projectURL)
    }

    public static func status(projectURL: URL, target: AgentPolicyTarget) -> AgentPolicyStatus {
        let url = target.policyURL(projectURL: projectURL)
        if target == .cursor {
            return AgentPolicyStatus(
                target: target,
                path: url.path,
                installed: CursorRulesInstaller.isInstalled(projectURL: projectURL),
                needsUpdate: CursorRulesInstaller.needsUpdate(projectURL: projectURL)
            )
        }
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let installed = text.contains(AgentsMarkdownGenerator.marker)
        let current = text.contains("Policy version: \(AgentsMarkdownGenerator.version)")
        return AgentPolicyStatus(target: target, path: url.path, installed: installed, needsUpdate: !current)
    }

    public static func policyBody(target: AgentPolicyTarget, projectName: String) -> String {
        """
        \(AgentsMarkdownGenerator.marker)
        ## Secrets (Vibe Vault)

        Project: **\(projectName)**
        Policy version: \(AgentsMarkdownGenerator.version)

        - Use Vibe Vault for real API keys and tokens.
        - Run `vibevault scan` before secret-dependent work in this repo.
        - Do not create `.env` / `.env.*` files with real secret values.
        - If a secret is missing, ask the user to import it into Vibe Vault; never ask them to paste the raw value into chat.
        - Use Vibe Vault MCP or `vibevault run -- <command>` for scoped access.
        - Keep `.env.example` only for required names and safe defaults.

        \(AgentsMarkdownGenerator.endMarker)
        """
    }

    private static func result(_ target: AgentPolicyTarget, _ projectURL: URL) -> AgentPolicyInstallResult {
        AgentPolicyInstallResult(target: target, path: target.policyURL(projectURL: projectURL).path, installed: true)
    }

    private static func append(_ body: String, to existing: String) -> String {
        let base = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let section = body.hasSuffix("\n") ? body : body + "\n"
        if base.isEmpty { return section }
        return base + "\n\n" + section
    }
}
