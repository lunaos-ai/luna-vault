import AppKit
import Foundation

/// Soft UI feedback: Trackpad haptic + optional quiet system sounds.
enum Feedback {
    enum Kind {
        case success   // copy, prepare, import done
        case select    // sidebar / chip
        case caution   // leak banner, error toast
        case tick      // toggle, reconcile check
    }

    static func play(_ kind: Kind, soundsEnabled: Bool) {
        haptic(for: kind)
        guard soundsEnabled else { return }
        let name: NSSound.Name?
        switch kind {
        case .success: name = NSSound.Name("Tink")
        case .select: name = NSSound.Name("Pop")
        case .caution: name = NSSound.Name("Funk")
        case .tick: name = NSSound.Name("Blow")
        }
        guard let name, let sound = NSSound(named: name) else { return }
        sound.volume = 0.28
        sound.play()
    }

    private static func haptic(for kind: Kind) {
        let pattern: NSHapticFeedbackManager.FeedbackPattern
        switch kind {
        case .success, .tick: pattern = .levelChange
        case .select: pattern = .alignment
        case .caution: pattern = .generic
        }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
