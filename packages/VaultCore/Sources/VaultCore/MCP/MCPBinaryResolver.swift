import Foundation

/// Resolves `vibevault-mcp` for CLI install/test and Cursor prepare.
public enum MCPBinaryResolver {
    public static func resolve(cliArgument: String = CommandLine.arguments[0]) -> String? {
        let fm = FileManager.default
        for path in candidates(cliArgument: cliArgument) where fm.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    public static func candidates(cliArgument: String) -> [String] {
        let exe = URL(fileURLWithPath: cliArgument).standardizedFileURL
        let dir = exe.deletingLastPathComponent()
        var paths: [String] = [
            dir.appendingPathComponent("vibevault-mcp").path,
            // App bundle: Helpers/vibevault → ../MacOS/vibevault-mcp
            dir.deletingLastPathComponent().appendingPathComponent("MacOS/vibevault-mcp").path,
            Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/vibevault-mcp").path
        ]
        let cwd = FileManager.default.currentDirectoryPath
        for rel in [".build/release/vibevault-mcp", ".build/debug/vibevault-mcp"] {
            paths.append((cwd as NSString).appendingPathComponent(rel))
        }
        paths.append("/usr/local/bin/vibevault-mcp")
        paths.append("/opt/homebrew/bin/vibevault-mcp")
        return paths
    }
}
