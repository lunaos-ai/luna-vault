import Foundation
import VaultCore

final class MCPServer {
    private var context: MCPContext
    private let agentDetector: MCPAgentDetector?
    private let stdout = FileHandle.standardOutput

    init(context: MCPContext, agentDetector: MCPAgentDetector? = nil) {
        self.context = context
        self.agentDetector = agentDetector
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
            if let params = request.params?.asObject(),
               let info = params["clientInfo"] as? [String: Any],
               let name = info["name"] as? String {
                let canonical = MCPClientMapper.canonical(from: name)
                context.clientName = canonical
                agentDetector?.setMCPClientName(name)
            }
            respond(request: request, result: AnyCodable([
                "protocolVersion": MCP.protocolVersion,
                "capabilities": [
                    "tools": [:] as [String: Any],
                    "resources": [:] as [String: Any],
                    "prompts": [:] as [String: Any]
                ] as [String: Any],
                "serverInfo": ["name": MCP.serverName, "version": MCP.serverVersion]
            ]))
        case "initialized", "notifications/initialized":
            break
        case "tools/list":
            let tools = MCPTools.definitions.map { def -> [String: Any] in
                ["name": def.name, "description": def.description, "inputSchema": def.inputSchema]
            }
            respond(request: request, result: AnyCodable(["tools": tools]))
        case "resources/list":
            respond(request: request, result: AnyCodable(["resources": MCPResources.list()]))
        case "resources/read":
            guard let params = request.params?.asObject(),
                  let uri = params["uri"] as? String,
                  let result = MCPResources.read(uri: uri) else {
                respondError(request: request, error: .invalidParams("uri required"))
                return
            }
            respond(request: request, result: AnyCodable(result))
        case "prompts/list":
            respond(request: request, result: AnyCodable(["prompts": MCPPrompts.list()]))
        case "prompts/get":
            guard let params = request.params?.asObject(),
                  let name = params["name"] as? String else {
                respondError(request: request, error: .invalidParams("name required"))
                return
            }
            var argMap: [String: String] = [:]
            if let raw = params["arguments"] as? [String: Any] {
                for (k, v) in raw { if let s = v as? String { argMap[k] = s } }
            }
            guard let result = MCPPrompts.get(name: name, args: argMap) else {
                respondError(request: request, error: .invalidParams("unknown prompt"))
                return
            }
            respond(request: request, result: AnyCodable(result))
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
