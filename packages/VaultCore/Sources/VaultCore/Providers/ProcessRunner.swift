import Foundation

public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Abstracts subprocess execution so providers can shell out to CLIs like
/// `wrangler` while staying unit-testable (inject a stub in tests).
public protocol ProcessRunner: Sendable {
    func run(executable: String, args: [String], stdin: Data?) throws -> ProcessResult
}

public struct SystemProcessRunner: ProcessRunner {
    public init() {}

    public func run(executable: String, args: [String], stdin: Data?) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args

        // Inherit the user's environment, then make sure node (wrangler's
        // interpreter) is reachable by prepending the binary's own directory.
        var env = ProcessInfo.processInfo.environment
        let binDir = (executable as NSString).deletingLastPathComponent
        env["PATH"] = "\(binDir):" + (env["PATH"] ?? "/usr/local/bin:/usr/bin:/bin")
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let inPipe: Pipe? = stdin == nil ? nil : Pipe()
        if let inPipe { process.standardInput = inPipe }

        // Drain stdout, stderr, and feed stdin concurrently. Reading the pipes
        // sequentially would deadlock: if the child fills the ~64KB stderr buffer
        // while we block on stdout (or vice versa), neither side can advance.
        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "dev.vibevault.process", attributes: .concurrent)

        try process.run()

        queue.async(group: group) { outData = outPipe.fileHandleForReading.readDataToEndOfFile() }
        queue.async(group: group) { errData = errPipe.fileHandleForReading.readDataToEndOfFile() }
        if let inPipe, let stdin {
            queue.async(group: group) {
                inPipe.fileHandleForWriting.write(stdin)
                try? inPipe.fileHandleForWriting.close()
            }
        }

        group.wait()
        process.waitUntilExit()

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
