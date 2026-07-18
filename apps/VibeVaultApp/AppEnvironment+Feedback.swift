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

    func bindUISoundsFromSettings() {
        uiSoundsEnabled = settings.uiSoundsEnabled
    }
}
