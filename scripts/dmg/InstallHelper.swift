// One-click installer shown in the DMG. Installs the app and its CLI helpers.
import AppKit
import Foundation

let appName = "VibeVault.app"
let destRoot = "/Applications"
let userBin = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".local/bin", isDirectory: true)

enum InstallerError: LocalizedError {
    case missingHelper(String)
    case commandFailed(String, Int32)

    var errorDescription: String? {
        switch self {
        case let .missingHelper(path): return "Installed app is missing \(path)."
        case let .commandFailed(command, status):
            return "\(command) exited with status \(status)."
        }
    }
}

func siblingApp() -> URL? {
    let bundle = Bundle.main.bundleURL
    let parent = bundle.deletingLastPathComponent()
  return FileManager.default.fileExists(atPath: parent.appendingPathComponent(appName).path)
        ? parent.appendingPathComponent(appName) : nil
}

func copyWithProgress(from src: URL, to dest: URL) throws {
    let fm = FileManager.default
    if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
    let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 360, height: 120),
        styleMask: [.titled, .nonactivatingPanel],
        backing: .buffered, defer: false
    )
    panel.title = "Installing Vibe Vault"
    panel.isFloatingPanel = true
    let label = NSTextField(labelWithString: "Copying to Applications…")
    label.frame = NSRect(x: 24, y: 72, width: 312, height: 20)
    let bar = NSProgressIndicator(frame: NSRect(x: 24, y: 36, width: 312, height: 20))
    bar.isIndeterminate = true
    panel.contentView?.addSubview(label)
    panel.contentView?.addSubview(bar)
    panel.center()
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    bar.startAnimation(nil)
    try fm.copyItem(at: src, to: dest)
    bar.stopAnimation(nil)
    label.stringValue = "Installed to Applications."
    Thread.sleep(forTimeInterval: 0.6)
    panel.orderOut(nil)
}

func installToolLinks(for app: URL) throws {
    let tools = [
        ("Contents/Helpers/vibevault", "vibevault"),
        ("Contents/MacOS/vibevault-mcp", "vibevault-mcp"),
        ("Contents/Helpers/vibevault-browser-host", "vibevault-browser-host")
    ]
    let fm = FileManager.default
    try fm.createDirectory(at: userBin, withIntermediateDirectories: true)

    for (relativeSource, name) in tools {
        let source = app.appendingPathComponent(relativeSource)
        guard fm.isExecutableFile(atPath: source.path) else {
            throw InstallerError.missingHelper(relativeSource)
        }
        let destination = userBin.appendingPathComponent(name)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        } else if (try? fm.destinationOfSymbolicLink(atPath: destination.path)) != nil {
            try fm.removeItem(at: destination)
        }
        try fm.createSymbolicLink(at: destination, withDestinationURL: source)
    }
}

func addUserBinToPath() throws {
    let profile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zprofile")
    let marker = "# Vibe Vault CLI"
    let line = "export PATH=\"$HOME/.local/bin:$PATH\""
    let existing = (try? String(contentsOf: profile, encoding: .utf8)) ?? ""
    guard !existing.contains(marker) && !existing.contains("$HOME/.local/bin") else { return }
    let suffix = existing.hasSuffix("\n") || existing.isEmpty ? "" : "\n"
    try (existing + suffix + "\(marker)\n\(line)\n").write(to: profile, atomically: true, encoding: .utf8)
}

func installMCPConfiguration(for app: URL) throws {
    let cli = app.appendingPathComponent("Contents/Helpers/vibevault")
    let mcp = app.appendingPathComponent("Contents/MacOS/vibevault-mcp")
    let process = Process()
    process.executableURL = cli
    process.arguments = ["mcp", "install", "--client", "all", "--binary", mcp.path]
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw InstallerError.commandFailed("MCP configuration", process.terminationStatus)
    }
}

@main
struct InstallerMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        guard let src = siblingApp() else {
            alert("VibeVault.app not found on this disk image.")
            exit(1)
        }
        let dest = URL(fileURLWithPath: destRoot).appendingPathComponent(appName)
        do {
            try copyWithProgress(from: src, to: dest)
            try installToolLinks(for: dest)
            try addUserBinToPath()
            try installMCPConfiguration(for: dest)
            let open = alert(
                "Vibe Vault, CLI, MCP, and browser host are installed.",
                buttons: ["Open Vibe Vault", "Close"],
                style: .informational
            )
            if open == .alertFirstButtonReturn {
                NSWorkspace.shared.openApplication(at: dest, configuration: .init())
            }
        } catch {
            alert("App installed, but setup needs attention: \(error.localizedDescription)")
            exit(1)
        }
        NSApp.terminate(nil)
    }

    @discardableResult
    static func alert(
        _ msg: String,
        buttons: [String] = ["OK"],
        style: NSAlert.Style = .warning
    ) -> NSApplication.ModalResponse {
        let a = NSAlert()
        a.messageText = "Vibe Vault"
        a.informativeText = msg
        a.alertStyle = style
        buttons.forEach { a.addButton(withTitle: $0) }
        return a.runModal()
    }
}
