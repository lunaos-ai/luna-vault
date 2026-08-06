import Foundation

enum EnvInjector {
    /// Spawns a child process, merging the supplied env, and returns its exit code.
    static func spawn(args: [String], env: [String: String]) throws -> Int32 {
        guard let executable = resolveExecutable(args[0]) else {
            FileHandle.standardError.write(Data("command not found: \(args[0])\n".utf8))
            return 127
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(args.dropFirst())
        process.environment = env
        // Interactive children must be able to read the operator's terminal.
        // Inheriting our own fd 0 breaks silently when the CLI is launched
        // through wrappers or app helpers that hold or replace stdin — the
        // child's prompt blocks forever while typed input goes nowhere.
        // When stdin is a terminal, hand the child a fresh handle to the
        // controlling terminal instead; keep plain inheritance when stdin
        // is a pipe so `cat x | vibevault run -- cmd` still works.
        if isatty(FileHandle.standardInput.fileDescriptor) != 0,
           let tty = FileHandle(forUpdatingAtPath: "/dev/tty") {
            process.standardInput = tty
        } else {
            process.standardInput = FileHandle.standardInput
        }
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    private static func resolveExecutable(_ name: String) -> String? {
        if name.hasPrefix("/") || name.hasPrefix("./") || name.hasPrefix("../") {
            return FileManager.default.isExecutableFile(atPath: name) ? name : nil
        }
        let pathVar = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/local/bin"
        for dir in pathVar.split(separator: ":") {
            let candidate = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }
}
