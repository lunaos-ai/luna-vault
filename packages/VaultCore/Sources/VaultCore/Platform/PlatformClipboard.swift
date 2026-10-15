import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if os(Windows)
import WinSDK
import ucrt
#endif

public enum PlatformClipboard {
    public static func copy(_ text: String) -> Bool {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
        #elseif os(Windows)
        return copyWindows(text)
        #else
        return copyUnixCommand(text)
        #endif
    }

    public static func readString() -> String? {
        #if canImport(AppKit)
        return NSPasteboard.general.string(forType: .string)
        #elseif os(Windows)
        return readWindows()
        #else
        return readUnixCommand()
        #endif
    }

    #if os(Windows)
    private static func copyWindows(_ text: String) -> Bool {
        let chars = Array(text.utf16) + [0]
        let bytes = chars.count * MemoryLayout<UInt16>.size
        guard OpenClipboard(nil), EmptyClipboard() else { return false }
        defer { CloseClipboard() }
        guard let handle = GlobalAlloc(DWORD(GMEM_MOVEABLE), SIZE_T(bytes)) else { return false }
        guard let locked = GlobalLock(handle) else {
            _ = GlobalFree(handle)
            return false
        }
        memcpy(locked, chars, bytes)
        _ = GlobalUnlock(handle)
        if SetClipboardData(DWORD(CF_UNICODETEXT), handle) == nil {
            _ = GlobalFree(handle)
            return false
        }
        return true
    }

    private static func readWindows() -> String? {
        guard OpenClipboard(nil) else { return nil }
        defer { CloseClipboard() }
        guard let handle = GetClipboardData(DWORD(CF_UNICODETEXT)) else { return nil }
        guard let locked = GlobalLock(handle) else { return nil }
        defer { _ = GlobalUnlock(handle) }
        return String(decodingCString: locked.assumingMemoryBound(to: UInt16.self), as: UTF16.self)
    }
    #endif

    #if !os(Windows) && !canImport(AppKit)
    private static func copyUnixCommand(_ text: String) -> Bool {
        let tools = ["/usr/bin/wl-copy", "/usr/bin/xclip"]
        for tool in tools where FileManager.default.isExecutableFile(atPath: tool) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            if tool.hasSuffix("xclip") { process.arguments = ["-selection", "clipboard"] }
            let pipe = Pipe()
            process.standardInput = pipe
            do {
                try process.run()
                try pipe.fileHandleForWriting.write(contentsOf: Data(text.utf8))
                try pipe.fileHandleForWriting.close()
                process.waitUntilExit()
                if process.terminationStatus == 0 { return true }
            } catch {
                continue
            }
        }
        return false
    }

    private static func readUnixCommand() -> String? {
        let tools: [(path: String, args: [String])] = [
            ("/usr/bin/wl-paste", []),
            ("/usr/bin/xclip", ["-selection", "clipboard", "-o"])
        ]
        for tool in tools where FileManager.default.isExecutableFile(atPath: tool.path) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool.path)
            process.arguments = tool.args
            let stdout = Pipe()
            process.standardOutput = stdout
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { continue }
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                if let text = String(data: data, encoding: .utf8), !text.isEmpty { return text }
            } catch {
                continue
            }
        }
        return nil
    }
    #endif
}
