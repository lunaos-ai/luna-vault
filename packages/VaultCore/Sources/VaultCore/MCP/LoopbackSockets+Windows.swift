#if os(Windows)
import Foundation
import WinSDK

typealias LoopbackFD = SOCKET

enum LoopbackSockets {
    static let invalid: LoopbackFD = INVALID_SOCKET
    private static let wsa: Void = {
        var data = WSADATA()
        _ = WSAStartup(MAKEWORD(2, 2), &data)
    }()

    static func startListen(port: UInt16) throws -> LoopbackFD {
        _ = wsa
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd != INVALID_SOCKET else { throw MCPSandboxError.listenFailed("socket") }
        var reuse: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, Int32(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = ADDRESS_FAMILY(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.S_un.S_addr = 0x0100007F
        let bindResult = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, Int32(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0, listen(fd, 16) == 0 else {
            closeFD(fd)
            throw MCPSandboxError.listenFailed("bind \(port)")
        }
        return fd
    }

    static func acceptClient(_ listenFD: LoopbackFD) -> (LoopbackFD, Bool)? {
        var addr = sockaddr_in()
        var len = Int32(MemoryLayout<sockaddr_in>.size)
        let client = withUnsafeMutablePointer(to: &addr) { pointer -> LoopbackFD in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                WinSDK.accept(listenFD, $0, &len)
            }
        }
        guard client != INVALID_SOCKET else { return nil }
        return (client, addr.sin_addr.S_un.S_addr == 0x0100007F)
    }

    static func recv(_ fd: LoopbackFD, max: Int) -> Data? {
        var buffer = [UInt8](repeating: 0, count: max)
        let count = buffer.withUnsafeMutableBytes { raw -> Int32 in
            WinSDK.recv(fd, raw.baseAddress, Int32(max), 0)
        }
        guard count > 0 else { return count == 0 ? Data() : nil }
        return Data(buffer.prefix(Int(count)))
    }

    static func sendAll(_ fd: LoopbackFD, _ data: Data) {
        data.withUnsafeBytes { raw in
            var sent = 0
            let total = data.count
            while sent < total {
                let n = WinSDK.send(fd, raw.baseAddress?.advanced(by: sent), Int32(total - sent), 0)
                if n <= 0 { return }
                sent += Int(n)
            }
        }
    }

    static func closeFD(_ fd: LoopbackFD) {
        _ = closesocket(fd)
    }
}
#endif
