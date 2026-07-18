import Foundation

/// Spawns `pushci secret` in a project directory (local `.pushci/secrets.enc` store).
public enum PushciCLI {
    public typealias Runner = (_ projectPath: URL, _ args: [String]) throws -> String

    public static func listKeys(
        projectPath: URL,
        runner: Runner = defaultRunner
    ) throws -> [String] {
        let out = try runner(projectPath, ["secret", "list"])
        return parseListOutput(out)
    }

    public static func getValue(
        name: String,
        projectPath: URL,
        runner: Runner = defaultRunner
    ) throws -> String {
        let out = try runner(projectPath, ["secret", "get", name])
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PushciCLIError.emptyValue(name) }
        return trimmed
    }

    public static func setValue(
        name: String,
        value: String,
        projectPath: URL,
        runner: Runner = defaultRunner
    ) throws {
        _ = try runner(projectPath, ["secret", "set", name, value])
    }

    public static func parseListOutput(_ output: String) -> [String] {
        output.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.localizedCaseInsensitiveContains("no secrets") {
                return nil
            }
            let token = trimmed.split(separator: " ").last.map(String.init) ?? trimmed
            guard token.count >= 2, token.unicodeScalars.allSatisfy({
                CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).contains($0)
            }) else { return nil }
            return token
        }
    }

    public static func defaultRunner(projectPath: URL, args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["pushci"] + args
        process.currentDirectoryURL = projectPath
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw PushciCLIError.commandFailed(args.joined(separator: " "), stderr.isEmpty ? stdout : stderr)
        }
        return stdout
    }
}

public enum PushciCLIError: Error, CustomStringConvertible {
    case emptyValue(String)
    case commandFailed(String, String)
    case missingProjectPath

    public var description: String {
        switch self {
        case .emptyValue(let n): return "pushci returned empty value for \(n)"
        case .commandFailed(let cmd, let msg): return "pushci \(cmd): \(msg.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .missingProjectPath: return "missing project_path scope (PushCI project root)"
        }
    }
}
