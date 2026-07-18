import Foundation
import VaultCore

enum MCPConnectionTest {
    struct Result: Equatable {
        let ok: Bool
        let toolCount: Int
        let message: String
    }

    static func run(binaryPath: String) async -> Result {
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            return Result(ok: false, toolCount: 0, message: "Binary not executable: \(binaryPath)")
        }
        let process = Process()
        let pipeIn = Pipe()
        let pipeOut = Pipe()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.standardInput = pipeIn
        process.standardOutput = pipeOut
        process.standardError = Pipe()
        do { try process.run() } catch {
            return Result(ok: false, toolCount: 0, message: "\(error)")
        }
        let initReq = """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"Vibe Vault","version":"0.1"}}}
        """
        let listReq = """
        {"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
        """
        pipeIn.fileHandleForWriting.write(Data((initReq + "\n").utf8))
        pipeIn.fileHandleForWriting.write(Data((listReq + "\n").utf8))
        pipeIn.fileHandleForWriting.closeFile()
        let data = pipeOut.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(data: data, encoding: .utf8) ?? ""
        let count = text.components(separatedBy: "\"name\":\"list_secrets\"").count - 1 > 0
            ? countTools(in: text) : 0
        let ok = process.terminationStatus == 0 && count >= 4
        let msg = ok ? "MCP server responded with \(count) tools" : "Unexpected MCP response"
        return Result(ok: ok, toolCount: count, message: msg)
    }

    private static func countTools(in text: String) -> Int {
        guard let range = text.range(of: "\"tools\":[") else { return 0 }
        let tail = text[range.upperBound...]
        return tail.components(separatedBy: "\"name\":").count - 1
    }
}
