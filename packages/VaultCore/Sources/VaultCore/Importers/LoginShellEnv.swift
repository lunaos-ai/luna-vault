import Foundation

public enum LoginShellEnv {
    public static func snapshot(timeout: TimeInterval = 4) -> [String: String] {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: shell)
        task.arguments = ["-l", "-i", "-c", "env -0"]
        let stdout = Pipe()
        task.standardOutput = stdout
        // Discard stderr: a chatty shell profile (>64KB of rc warnings) would
        // otherwise fill an undrained stderr pipe and hang the shell forever.
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return [:] }

        // Drain stdout on a background thread so a large `env` dump can't fill
        // the pipe buffer while we poll, deadlocking before the process exits.
        let lock = NSLock()
        var data = Data()
        let reader = DispatchQueue(label: "dev.vibevault.shellenv")
        reader.async {
            let d = stdout.fileHandleForReading.readDataToEndOfFile()
            lock.lock(); data = d; lock.unlock()
        }

        let deadline = Date().addingTimeInterval(timeout)
        while task.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if task.isRunning {
            task.terminate()
            return [:]
        }
        task.waitUntilExit()
        reader.sync {}  // ensure the read finished
        lock.lock(); let captured = data; lock.unlock()
        guard task.terminationStatus == 0, let text = String(data: captured, encoding: .utf8) else {
            return [:]
        }
        return parse(nullDelimited: text)
    }

    static func parse(nullDelimited: String) -> [String: String] {
        var out: [String: String] = [:]
        for entry in nullDelimited.split(separator: "\0", omittingEmptySubsequences: true) {
            guard let eq = entry.firstIndex(of: "=") else { continue }
            let key = String(entry[..<eq])
            let value = String(entry[entry.index(after: eq)...])
            guard !key.isEmpty else { continue }
            out[key] = value
        }
        return out
    }
}
