import Foundation
import VaultCore

final class MCPServer {
    private var context: MCPContext
    private let stdin = FileHandle.standardInput
    private let stdout = FileHandle.standardOutput
    private let stderr = FileHandle.standardError

    init(context: MCPContext) {
        self.context = context
    }

    func run() async {
        while let line = readLine(strippingNewline: true), !line.isEmpty {
            guard let data = line.data(using: .utf8) else { continue }
            do {
                let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
                await handle(request: request)
            } catch {
                let msg = "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32700,\"message\":\"Parse error: \(error)\"}}\n"
                try? stdout.write(contentsOf: Data(msg.utf8))
            }
        }
    }

    private func handle(request: JSONRPCRequest) async {
        switch request.method {
        case "initialize":
            // Capture client name from clientInfo.name if present.
            if let params = request.params?.asObject(),
               let info = params["clientInfo"] as? [String: Any],
               let name = info["name"] as? String {
                context.clientName = "mcp:\(name)"
            }
            respond(request: request, result: AnyCodable([
                "protocolVersion": MCP.protocolVersion,
                "capabilities": ["tools": [:] as [String: Any]] as [String: Any],
                "serverInfo": ["name": MCP.serverName, "version": MCP.serverVersion]
            ]))
        case "initialized", "notifications/initialized":
            break
        case "tools/list":
            let tools = MCPTools.definitions.map { def -> [String: Any] in
                ["name": def.name, "description": def.description, "inputSchema": def.inputSchema]
            }
            respond(request: request, result: AnyCodable(["tools": tools]))
        case "tools/call":
            guard let params = request.params?.asObject(),
                  let toolName = params["name"] as? String else {
                respondError(request: request, error: .invalidParams("name required"))
                return
            }
            let args = (params["arguments"] as? [String: Any]) ?? [:]
            let result = await MCPTools.call(name: toolName, arguments: args, context: context)
            respond(request: request, result: AnyCodable(result))
        case "ping":
            respond(request: request, result: AnyCodable([:] as [String: Any]))
        default:
            respondError(request: request, error: .methodNotFound(request.method))
        }
    }

    private func respond(request: JSONRPCRequest, result: AnyCodable?) {
        guard let id = request.id else { return }
        emit(JSONRPCResponse(id: id, result: result, error: nil))
    }

    private func respondError(request: JSONRPCRequest, error: JSONRPCError) {
        guard let id = request.id else { return }
        emit(JSONRPCResponse(id: id, result: nil, error: error))
    }

    private func emit<T: Encodable>(_ value: T) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? stdout.write(contentsOf: data)
        try? stdout.write(contentsOf: Data("\n".utf8))
    }
}
