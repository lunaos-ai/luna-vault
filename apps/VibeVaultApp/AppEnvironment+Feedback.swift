import AppKit
import Foundation

extension AppEnvironment {
    func showToast(_ message: String, feedback: Feedback.Kind = .success) {
        Feedback.play(feedback, soundsEnabled: uiSoundsEnabled)
        // Force a fresh toast even when the same message repeats (e.g. copy twice).
        toastMessage = nil
        DispatchQueue.main.async {
            self.toastMessage = message
        }
    }

    /// Copies the secret *name* only (no biometric / value read).
    func copySecretName(_ name: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(name, forType: .string)
        showToast("Copied name \(name)")
    }

    @MainActor
    @discardableResult
    func copyDotenvLine(name: String) async -> Bool {
        do {
            let fresh = try await service.read(name: name, reason: "Copy \(name) as KEY=value")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(name)=\(shellQuotedValue(fresh.value))", forType: .string)
            showToast("Copied dotenv line \(name)")
            return true
        } catch {
            lastError = "\(error)"
            showToast("Copy failed", feedback: .caution)
            return false
        }
    }

    func clearClipboard() {
        NSPasteboard.general.clearContents()
        showToast("Clipboard cleared", feedback: .tick)
    }

    func bindUISoundsFromSettings() {
        uiSoundsEnabled = settings.uiSoundsEnabled
    }

    private func shellQuotedValue(_ value: String) -> String {
        if value.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'#$`\\!"))) == nil {
            return value
        }
        return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
