import Foundation

/// HTTP/1.1 server bound to 127.0.0.1. Rejects non-loopback peers.
public final class LoopbackHTTPServer: @unchecked Sendable {
    public let port: UInt16
    private var listenFD: LoopbackFD = LoopbackSockets.invalid
    private var running = false

    public init(port: UInt16 = MCPSandboxSettings.defaultPort) {
        self.port = port
    }

    public func runBlocking(_ handler: @escaping (HTTPRequest) async -> HTTPResponse) throws {
        listenFD = try LoopbackSockets.startListen(port: port)
        running = true
        let line = "vibevault-mcp: \(MCPSandboxSettings.endpoint(port: port))\n"
        FileHandle.standardError.write(Data(line.utf8))
        while running {
            guard let (client, loopback) = LoopbackSockets.acceptClient(listenFD) else { continue }
            serve(client: client, loopback: loopback, handler: handler)
        }
    }

    public func stop() {
        running = false
        if listenFD != LoopbackSockets.invalid {
            LoopbackSockets.closeFD(listenFD)
            listenFD = LoopbackSockets.invalid
        }
    }

    private func serve(
        client: LoopbackFD,
        loopback: Bool,
        handler: @escaping (HTTPRequest) async -> HTTPResponse
    ) {
        defer { LoopbackSockets.closeFD(client) }
        guard loopback else {
            LoopbackSockets.sendAll(client, HTTPResponse(status: 403, reason: "Forbidden", body: Data("forbidden\n".utf8)).encode())
            return
        }
        guard let request = readRequest(from: client) else {
            LoopbackSockets.sendAll(client, HTTPResponse(status: 400, reason: "Bad Request", body: Data("bad request\n".utf8)).encode())
            return
        }
        let slot = HTTPResponseSlot()
        let lock = DispatchSemaphore(value: 0)
        Task {
            slot.value = await handler(request)
            lock.signal()
        }
        lock.wait()
        LoopbackSockets.sendAll(client, slot.value.encode())
    }

    private func readRequest(from fd: LoopbackFD) -> HTTPRequest? {
        var buffer = Data()
        while buffer.count <= MCPSandboxSettings.maxHTTPBodyBytes {
            guard let chunk = LoopbackSockets.recv(fd, max: 4096), !chunk.isEmpty else { break }
            buffer.append(chunk)
            switch HTTPRequestParser.parse(buffer) {
            case .incomplete:
                continue
            case .invalid:
                return nil
            case .complete(let request):
                return request
            }
        }
        return nil
    }
}

private final class HTTPResponseSlot: @unchecked Sendable {
    var value = HTTPResponse(status: 500, reason: "Internal Server Error")
}
