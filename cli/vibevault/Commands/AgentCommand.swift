import ArgumentParser
import Foundation
import VaultCore

struct AgentCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "Coordinate with other local AI-agent sessions.",
        subcommands: [
            AgentRegisterCommand.self,
            AgentPeersCommand.self,
            AgentLockCommand.self,
            AgentUnlockCommand.self,
            AgentAskCommand.self,
            AgentPollCommand.self,
            AgentNoteCommand.self,
            AgentNotesCommand.self,
            AgentCleanupCommand.self
        ]
    )
}

struct AgentRegisterCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "register")

    @Option(name: .long, help: "Repo path (default: current directory).")
    var repo: String?

    @Option(name: .long, help: "Worktree path (default: repo).")
    var worktree: String?

    @Option(name: .long, help: "Human-readable nickname for this session.")
    var nick: String?

    @Option(name: .long, parsing: .upToNextOption, help: "Capabilities (space-separated).")
    var capabilities: [String] = ["read", "write", "scan", "audit", "push", "pull"]

    mutating func run() async throws {
        CoordinationService.register(repo: repo, worktree: worktree, nick: nick, capabilities: capabilities)
    }
}

struct AgentPeersCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "peers")

    @Option(name: .long, help: "Filter to a repo path.")
    var repo: String?

    mutating func run() async throws {
        CoordinationService.peers(repo: repo)
    }
}

struct AgentLockCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "lock")

    @Argument(help: "Repo path to lock.")
    var repo: String

    mutating func run() async throws {
        guard CoordinationService.lock(repo: repo) else {
            throw ExitCode(1)
        }
    }
}

struct AgentUnlockCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "unlock")

    @Argument(help: "Repo path to unlock.")
    var repo: String

    mutating func run() async throws {
        guard CoordinationService.unlock(repo: repo) else {
            throw ExitCode(1)
        }
    }
}

struct AgentAskCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ask")

    @Option(name: .long, help: "Target session id.")
    var to: String

    @Option(name: .long, help: "Repo path the task relates to.")
    var repo: String

    @Option(name: .long, help: "Task description.")
    var task: String

    mutating func run() async throws {
        CoordinationService.ask(to: to, repo: repo, task: task)
    }
}

struct AgentPollCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "poll")

    @Option(name: .long, help: "Only accept responses from this session id.")
    var from: String?

    @Option(name: .long, help: "Timeout in seconds.")
    var timeout: Int = 300

    mutating func run() async throws {
        await CoordinationService.poll(from: from, timeout: timeout)
    }
}

struct AgentNoteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "note")

    @Option(name: .long, help: "Repo path the note belongs to.")
    var repo: String

    @Option(name: .long, help: "Note text.")
    var text: String

    mutating func run() async throws {
        CoordinationService.note(repo: repo, text: text)
    }
}

struct AgentNotesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "notes")

    @Option(name: .long, help: "Repo path.")
    var repo: String

    mutating func run() async throws {
        CoordinationService.notes(repo: repo)
    }
}

struct AgentCleanupCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "cleanup")

    mutating func run() async throws {
        CoordinationService.cleanup()
    }
}
