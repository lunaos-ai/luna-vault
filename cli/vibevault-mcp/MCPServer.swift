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
            let encoded = await handleBody(data)
            guard !encoded.isEmpty else { continue }
            try? stdout.write(contentsOf: encoded)
            try? stdout.write(contentsOf: Data("\n".utf8))
        }
    }

    func handleBody(_ data: Data) async -> Data {
        do {
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
            guard let response = await dispatch(request) else { return Data() }
            return (try? JSONEncoder().encode(response)) ?? Data()
        } catch {
            return Data("{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32700,\"message\":\"Parse error\"}}".utf8)
        }
    }

    private func dispatch(_ request: JSONRPCRequest) async -> JSONRPCResponse? {
        switch request.method {
        case "initialize":
            if let params = request.params?.asObject(),
               let info = params["clientInfo"] as? [String: Any],
               let name = info["name"] as? String {
                context.clientName = MCPClientMapper.canonical(from: name)
                agentDetector?.setMCPClientName(name)
            }
            return ok(request, [
                "protocolVersion": MCP.protocolVersion,
                "capabilities": [
                    "tools": [:] as [String: Any],
                    "resources": [:] as [String: Any],
                    "prompts": [:] as [String: Any]
                ] as [String: Any],
                "serverInfo": ["name": MCP.serverName, "version": MCP.serverVersion]
            ])
        case "initialized", "notifications/initialized":
            return nil
        case "tools/list":
            let tools = MCPTools.definitions.map { def -> [String: Any] in
                ["name": def.name, "description": def.description, "inputSchema": def.inputSchema]
            }
            return ok(request, ["tools": tools])
        case "resources/list":
            return ok(request, ["resources": MCPResources.list()])
        case "resources/read":
            guard let params = request.params?.asObject(),
                  let uri = params["uri"] as? String,
                  let result = MCPResources.read(uri: uri) else {
                return err(request, .invalidParams("uri required"))
            }
            return ok(request, result)
        case "prompts/list":
            return ok(request, ["prompts": MCPPrompts.list()])
        case "prompts/get":
            return promptGet(request)
        case "tools/call":
            return await toolCall(request)
        case "ping":
            return ok(request, [:] as [String: Any])
        default:
            return err(request, .methodNotFound(request.method))
        }
    }

    private func promptGet(_ request: JSONRPCRequest) -> JSONRPCResponse? {
        guard let params = request.params?.asObject(),
              let name = params["name"] as? String else {
            return err(request, .invalidParams("name required"))
        }
        var argMap: [String: String] = [:]
        if let raw = params["arguments"] as? [String: Any] {
            for (k, v) in raw { if let s = v as? String { argMap[k] = s } }
        }
        guard let result = MCPPrompts.get(name: name, args: argMap) else {
            return err(request, .invalidParams("unknown prompt"))
        }
        return ok(request, result)
    }

    private func toolCall(_ request: JSONRPCRequest) async -> JSONRPCResponse? {
        guard let params = request.params?.asObject(),
              let toolName = params["name"] as? String else {
            return err(request, .invalidParams("name required"))
        }
        let args = (params["arguments"] as? [String: Any]) ?? [:]
        let result = await MCPTools.call(name: toolName, arguments: args, context: context)
        return ok(request, result)
    }

    private func ok(_ request: JSONRPCRequest, _ result: [String: Any]) -> JSONRPCResponse? {
        guard let id = request.id else { return nil }
        return JSONRPCResponse(id: id, result: AnyCodable(result), error: nil)
    }

    private func err(_ request: JSONRPCRequest, _ error: JSONRPCError) -> JSONRPCResponse? {
        guard let id = request.id else { return nil }
        return JSONRPCResponse(id: id, result: nil, error: error)
    }
}
