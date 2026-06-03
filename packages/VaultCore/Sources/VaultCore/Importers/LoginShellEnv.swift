import Foundation

public enum LoginShellEnv {
    public static func snapshot(timeout: TimeInterval = 4) -> [String: String] {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: shell)
        task.arguments = ["-l", "-i", "-c", "env -0"]
        let stdout = Pipe()
        task.standardOutput = stdout
        task.standardError = Pipe()
        do { try task.run() } catch { return [:] }

        let deadline = Date().addingTimeInterval(timeout)
        while task.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if task.isRunning {
            task.terminate()
            return [:]
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard task.terminationStatus == 0, let text = String(data: data, encoding: .utf8) else {
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
