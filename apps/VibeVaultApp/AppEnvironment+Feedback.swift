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

    func bindUISoundsFromSettings() {
        uiSoundsEnabled = settings.uiSoundsEnabled
    }
}
