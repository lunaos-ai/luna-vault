import Foundation

enum MCPBinaryLocator {
    /// Returns the absolute path of `vibevault-mcp` that AI clients should launch.
    static func resolve() -> String {
        // 1. Bundled inside the .app at Contents/MacOS/vibevault-mcp
        let exec = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/vibevault-mcp")
        if FileManager.default.isExecutableFile(atPath: exec.path) {
            return exec.path
        }
        // 2. Same directory as the running binary (SwiftPM build output).
        let exePath = ProcessInfo.processInfo.arguments.first ?? ""
        let exeDir = URL(fileURLWithPath: exePath).deletingLastPathComponent()
        let sibling = exeDir.appendingPathComponent("vibevault-mcp")
        if FileManager.default.isExecutableFile(atPath: sibling.path) {
            return sibling.path
        }
        // 3. PATH lookup
        let pathVar = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin"
        for dir in pathVar.split(separator: ":") {
            let candidate = "\(dir)/vibevault-mcp"
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        // 4. Fallback to bundled path (even if missing); user sees the path and can fix.
        return exec.path
    }
}
