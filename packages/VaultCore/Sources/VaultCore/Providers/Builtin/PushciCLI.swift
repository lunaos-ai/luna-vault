import Foundation

/// Spawns `pushci secret` in a project directory (local `.pushci/secrets.enc` store).
public enum PushciCLI {
    /// Runs `pushci` with `args`, optionally feeding `input` to its stdin.
    ///
    /// Secret values travel through `input`, never through `args`: anything in
    /// `args` lands in the process table, where any local process can read it
    /// with `ps`, and in `pushci`'s own audit receipts.
    public typealias Runner = (_ projectPath: URL, _ args: [String], _ input: String?) throws -> String

    public static func listKeys(
        projectPath: URL,
        runner: Runner = defaultRunner
    ) throws -> [String] {
        let out = try runner(projectPath, ["secret", "list"], nil)
        return parseListOutput(out)
    }

    public static func getValue(
        name: String,
        projectPath: URL,
        runner: Runner = defaultRunner
    ) throws -> String {
        let out = try runner(projectPath, ["secret", "get", name], nil)
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PushciCLIError.emptyValue(name) }
        return trimmed
    }

    /// Stores a secret by piping the value to `pushci secret set --from-stdin`.
    ///
    /// `pushci` rejects a positionally-supplied value outright, so passing it
    /// as an argument never worked — it only exposed the value in argv and
    /// echoed it back in the failure message.
    public static func setValue(
        name: String,
        value: String,
        projectPath: URL,
        runner: Runner = defaultRunner
    ) throws {
        _ = try runner(projectPath, ["secret", "set", name, "--from-stdin"], value)
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

    public static func defaultRunner(projectPath: URL, args: [String], input: String?) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["pushci"] + args
        process.currentDirectoryURL = projectPath
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        // Only replace stdin when there is something to write. Left inherited,
        // `pushci` keeps whatever terminal the caller had, which its policy
        // gate needs in order to ask for approval.
        var stdinPipe: Pipe?
        if input != nil {
            let pipe = Pipe()
            process.standardInput = pipe
            stdinPipe = pipe
        }

        try process.run()

        if let pipe = stdinPipe, let value = input {
            pipe.fileHandleForWriting.write(Data(value.utf8))
            try? pipe.fileHandleForWriting.close()
        }

        // Drain both pipes before waiting: a child that fills a pipe buffer
        // blocks forever if the parent is already in waitUntilExit().
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw PushciCLIError.commandFailed(describe(args), stderr.isEmpty ? stdout : stderr)
        }
        return stdout
    }

    /// Renders a command for error messages. Only the flags and the secret
    /// *name* survive; any unexpected positional operand is replaced, so a
    /// value can never reach a log, a UI, or a bug report through an error.
    static func describe(_ args: [String]) -> String {
        guard args.first == "secret", args.count > 2 else {
            return args.joined(separator: " ")
        }
        let head = Array(args.prefix(3))
        let rest = args.dropFirst(3).map { $0.hasPrefix("-") ? $0 : "<redacted>" }
        return (head + rest).joined(separator: " ")
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
