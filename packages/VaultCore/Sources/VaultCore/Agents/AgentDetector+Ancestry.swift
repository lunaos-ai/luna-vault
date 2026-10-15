import Foundation
#if canImport(Darwin)
import Darwin
#endif

extension AgentDetector {
    /// Parent chain used to catch `zsh` spawned by `cursor-agent` / `claude`.
    public static func lookupAncestorProcesses() -> [String] {
        lookupAncestorProcesses(limit: 8)
    }

    static func lookupAncestorProcesses(limit: Int) -> [String] {
        #if os(Windows)
        return lookupWindowsAncestorProcesses(limit: limit)
        #elseif os(Linux)
        return lookupLinuxAncestorProcesses(limit: limit)
        #elseif canImport(Darwin)
        return lookupDarwinAncestorProcesses(limit: limit)
        #else
        return []
        #endif
    }

    #if canImport(Darwin) && !os(Windows)
    private static func lookupDarwinAncestorProcesses(limit: Int) -> [String] {
        var pid = getppid()
        var paths: [String] = []
        var seen = Set<Int32>()
        for _ in 0..<limit {
            if pid <= 1 || !seen.insert(pid).inserted { break }
            var buffer = [CChar](repeating: 0, count: 4096)
            let size = proc_pidpath(pid, &buffer, UInt32(buffer.count))
            if size > 0 {
                paths.append(String(cString: buffer))
            }
            pid = darwinParentPID(of: pid) ?? 0
        }
        return paths
    }

    private static func darwinParentPID(of pid: Int32) -> Int32? {
        var kinfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let ok = sysctl(&mib, u_int(mib.count), &kinfo, &size, nil, 0)
        guard ok == 0 else { return nil }
        return kinfo.kp_eproc.e_ppid
    }
    #endif

    #if os(Linux)
    static func lookupLinuxAncestorProcesses(limit: Int) -> [String] {
        var pid = linuxPPID(of: "self") ?? 0
        var paths: [String] = []
        var seen = Set<Int32>()
        for _ in 0..<limit {
            if pid <= 1 || !seen.insert(pid).inserted { break }
            if let comm = try? String(contentsOfFile: "/proc/\(pid)/comm", encoding: .utf8) {
                paths.append(comm.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            pid = linuxPPID(of: "\(pid)") ?? 0
        }
        return paths
    }

    private static func linuxPPID(of token: String) -> Int32? {
        guard let stat = try? String(contentsOfFile: "/proc/\(token)/stat", encoding: .utf8) else {
            return nil
        }
        let parts = stat.split(separator: " ")
        guard parts.count > 3, let ppid = Int32(parts[3]) else { return nil }
        return ppid
    }
    #endif
}
