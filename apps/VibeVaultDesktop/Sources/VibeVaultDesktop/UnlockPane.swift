import Foundation
import SwiftCrossUI
import VaultCore

struct UnlockPane: View {
    @Binding var model: DesktopModel
    var onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session unlock")
                .font(.system(size: 18, weight: .semibold))
            Text(model.unlockRemaining)
            Text(
                "On Linux and Windows there is no Touch ID. Create a time-bounded lease so CLI, MCP, and this app can read secrets."
            )
            .foregroundColor(.gray)
            HStack {
                Text("Minutes")
                TextField("30", text: $model.unlockMinutes)
                    .frame(width: 80)
            }
            HStack(spacing: 8) {
                Button("Unlock") { unlock() }
                Button("Lock now") { lock() }
            }
            Spacer()
        }
        .padding(8)
    }

    private func unlock() {
        let minutes = Int(model.unlockMinutes) ?? 30
        do {
            let status = try SharedUnlockSession.unlock(for: TimeInterval(minutes * 60))
            let left = Int(status.remainingSeconds() / 60)
            model.statusMessage = "Unlocked for \(left) minutes"
            model.errorMessage = nil
            onRefresh()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func lock() {
        SharedUnlockSession.lock()
        model.statusMessage = "Session locked"
        model.errorMessage = nil
        onRefresh()
    }
}
