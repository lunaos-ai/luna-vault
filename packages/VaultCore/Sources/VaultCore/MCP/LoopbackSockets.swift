#if !os(Windows)
import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

typealias LoopbackFD = Int32

enum LoopbackSockets {
    static let invalid: LoopbackFD = -1

    static func startListen(port: UInt16) throws -> LoopbackFD {
        let fd = socket(AF_INET, streamType, 0)
        guard fd >= 0 else { throw MCPSandboxError.listenFailed("socket") }
        var reuse: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bindResult = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
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
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let client = withUnsafeMutablePointer(to: &addr) { pointer -> LoopbackFD in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(listenFD, $0, &len)
            }
        }
        guard client >= 0 else { return nil }
        let loopback = addr.sin_addr.s_addr == inet_addr("127.0.0.1")
        return (client, loopback)
    }

    static func recv(_ fd: LoopbackFD, max: Int) -> Data? {
        var buffer = [UInt8](repeating: 0, count: max)
        let count = read(fd, &buffer, max)
        guard count > 0 else { return count == 0 ? Data() : nil }
        return Data(buffer.prefix(Int(count)))
    }

    static func sendAll(_ fd: LoopbackFD, _ data: Data) {
        data.withUnsafeBytes { raw in
            var sent = 0
            let total = data.count
            let base = raw.bindMemory(to: UInt8.self).baseAddress
            while sent < total {
                let n = write(fd, base?.advanced(by: sent), total - sent)
                if n <= 0 { return }
                sent += n
            }
        }
    }

    static func closeFD(_ fd: LoopbackFD) {
        _ = close(fd)
    }

    private static var streamType: Int32 {
        #if canImport(Glibc)
        Int32(SOCK_STREAM.rawValue)
        #else
        SOCK_STREAM
        #endif
    }
}
#endif
