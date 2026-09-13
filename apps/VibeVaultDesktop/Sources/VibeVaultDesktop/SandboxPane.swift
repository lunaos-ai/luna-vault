import Foundation
import SwiftCrossUI
import VaultCore

struct SandboxPane: View {
    @Binding var model: DesktopModel
    var onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sandbox MCP")
                .font(.system(size: 18, weight: .semibold))
            Text(model.sandboxStatus)
            Text(
                "AI sandboxes cannot spawn local MCP. Enroll a passkey, then start loopback HTTP on 127.0.0.1:17832. The sandbox sends the bearer token or Passkey header. Allowlisted secrets still apply."
            )
            .foregroundColor(.gray)
            TextField("Passkey (min 12)", text: $model.passkey)
            TextField("Confirm passkey", text: $model.passkeyConfirm)
            HStack {
                Text("Minutes")
                TextField("30", text: $model.sandboxMinutes)
                    .frame(width: 80)
            }
            HStack(spacing: 8) {
                Button("Enroll passkey") { enroll() }
                Button("Start") { start() }
                Button("Stop") { stop() }
            }
            Spacer()
        }
        .padding(8)
    }

    private func enroll() {
        do {
            try DesktopSandbox.enroll(passkey: model.passkey, confirm: model.passkeyConfirm)
            model.passkey = ""
            model.passkeyConfirm = ""
            model.statusMessage = "Sandbox passkey enrolled"
            model.errorMessage = nil
            onRefresh()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func start() {
        let minutes = Int(model.sandboxMinutes) ?? MCPSandboxSettings.defaultTokenMinutes
        do {
            let token = try DesktopSandbox.start(passkey: model.passkey, minutes: minutes)
            model.passkey = ""
            model.statusMessage =
                "Listening on \(MCPSandboxSettings.endpoint()) until \(PlatformDateFormat.logTimestamp(token.expiresAt))"
            model.errorMessage = nil
            onRefresh()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func stop() {
        DesktopSandbox.stop()
        model.statusMessage = "Sandbox MCP stopped"
        model.errorMessage = nil
        onRefresh()
    }
}
