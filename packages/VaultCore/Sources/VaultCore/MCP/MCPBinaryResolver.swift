import Foundation

/// Resolves `vibevault-mcp` for CLI install/test and Cursor prepare.
public enum MCPBinaryResolver {
    public static func binaryName() -> String {
        #if os(Windows)
        return "vibevault-mcp.exe"
        #else
        return "vibevault-mcp"
        #endif
    }

    public static func resolve(cliArgument: String = CommandLine.arguments[0]) -> String? {
        let fm = FileManager.default
        for path in candidates(cliArgument: cliArgument) where fm.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    public static func candidates(cliArgument: String) -> [String] {
        let mcp = binaryName()
        let exe = URL(fileURLWithPath: cliArgument).standardizedFileURL
        let dir = exe.deletingLastPathComponent()
        var paths: [String] = [
            dir.appendingPathComponent(mcp).path,
            dir.appendingPathComponent("vibevault-mcp").path,
            dir.deletingLastPathComponent().appendingPathComponent("MacOS/\(mcp)").path,
            Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/\(mcp)").path
        ]
        let cwd = FileManager.default.currentDirectoryPath
        for rel in [".build/release/\(mcp)", ".build/debug/\(mcp)",
                    ".build/release/vibevault-mcp", ".build/debug/vibevault-mcp"] {
            paths.append((cwd as NSString).appendingPathComponent(rel))
        }
        paths.append("/usr/local/bin/\(mcp)")
        paths.append("/opt/homebrew/bin/\(mcp)")
        let pathVar = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin"
        #if os(Windows)
        let separator: Character = ";"
        #else
        let separator: Character = ":"
        #endif
        for dir in pathVar.split(separator: separator) {
            paths.append("\(dir)/\(mcp)")
        }
        return paths
    }
}
