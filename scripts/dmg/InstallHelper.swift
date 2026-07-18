// One-click installer shown in the DMG. Copies VibeVault.app to /Applications.
import AppKit
import Foundation

let appName = "VibeVault.app"
let destRoot = "/Applications"

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
            let open = alert(
                "Vibe Vault is installed in Applications.",
                buttons: ["Open Vibe Vault", "Close"],
                style: .informational
            )
            if open == .alertFirstButtonReturn {
                NSWorkspace.shared.openApplication(at: dest, configuration: .init())
            }
        } catch {
            alert("Install failed: \(error.localizedDescription)")
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
