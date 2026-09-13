#if os(Windows)
import WinSDK

extension AgentDetector {
    static func lookupWindowsParentProcess() -> String? {
        let pid = GetCurrentProcessId()
        let snap = CreateToolhelp32Snapshot(DWORD(TH32CS_SNAPPROCESS), 0)
        guard snap != INVALID_HANDLE_VALUE else { return nil }
        defer { CloseHandle(snap) }
        var entry = PROCESSENTRY32()
        entry.dwSize = DWORD(MemoryLayout<PROCESSENTRY32>.stride)
        guard Process32First(snap, &entry) else { return nil }
        var parent: DWORD = 0
        repeat {
            if entry.th32ProcessID == pid {
                parent = entry.th32ParentProcessID
                break
            }
        } while Process32Next(snap, &entry)
        guard parent != 0 else { return nil }
        entry.dwSize = DWORD(MemoryLayout<PROCESSENTRY32>.stride)
        guard Process32First(snap, &entry) else { return nil }
        repeat {
            if entry.th32ProcessID == parent {
                return withUnsafePointer(to: &entry.szExeFile) { ptr in
                    ptr.withMemoryRebound(to: WCHAR.self, capacity: Int(MAX_PATH)) { wstr in
                        String(decodingCString: wstr, as: UTF16.self)
                    }
                }
            }
        } while Process32Next(snap, &entry)
        return nil
    }
}
#endif
