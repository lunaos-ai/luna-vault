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
    #endif
}
