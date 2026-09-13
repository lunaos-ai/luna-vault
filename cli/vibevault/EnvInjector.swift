import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

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
        attachStdio(process)
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    private static func attachStdio(_ process: Process) {
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        #if os(Windows)
        process.standardInput = FileHandle.standardInput
        #else
        if isatty(FileHandle.standardInput.fileDescriptor) != 0,
           let tty = FileHandle(forUpdatingAtPath: "/dev/tty") {
            process.standardInput = tty
        } else {
            process.standardInput = FileHandle.standardInput
        }
        #endif
    }

    private static func resolveExecutable(_ name: String) -> String? {
        if isExplicitPath(name) {
            return FileManager.default.isExecutableFile(atPath: name) ? name : nil
        }
        #if os(Windows)
        let pathVar = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let dirs = pathVar.split(separator: ";").map(String.init)
        let pathext = (ProcessInfo.processInfo.environment["PATHEXT"] ?? ".EXE;.CMD;.BAT")
            .split(separator: ";")
            .map(String.init)
        for dir in dirs {
            let base = URL(fileURLWithPath: dir).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: base) { return base }
            for ext in pathext {
                let candidate = base.lowercased().hasSuffix(ext.lowercased()) ? base : base + ext
                if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
            }
        }
        return nil
        #else
        let pathVar = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/local/bin"
        for dir in pathVar.split(separator: ":") {
            let candidate = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
        #endif
    }

    private static func isExplicitPath(_ name: String) -> Bool {
        #if os(Windows)
        name.contains("/") || name.contains("\\") || name.contains(":")
        #else
        name.hasPrefix("/") || name.hasPrefix("./") || name.hasPrefix("../")
        #endif
    }
}
