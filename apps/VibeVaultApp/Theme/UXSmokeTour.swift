import SwiftUI

/// Automated visual walkthrough of every main pane — animations + optional sounds.
@MainActor
enum UXSmokeTour {
    static func run(
        setSelection: @escaping (SidebarItem) -> Void,
        env: AppEnvironment
    ) async {
        let steps: [(SidebarItem, String)] = [
            (.overview, "Overview · greeting & quick actions"),
            (.vault, "Vault · list & search"),
            (.importSecrets, "Import · clipboard & dotenv"),
            (.projects, "Projects · scan & prepare"),
            (.providers, "Providers · Cloudflare / Vercel / PushCI"),
            (.aiAgents, "AI Agents · MCP & Cursor health"),
            (.audit, "Audit · agent chips"),
            (.settings, "Settings · feedback sounds"),
            (.overview, "Tour complete")
        ]
        Feedback.play(.tick, soundsEnabled: env.uiSoundsEnabled)
        for (item, caption) in steps {
            withAnimation(Motion.reveal) { setSelection(item) }
            Feedback.play(.select, soundsEnabled: env.uiSoundsEnabled)
            env.showToast(caption, feedback: .tick)
            try? await Task.sleep(nanoseconds: 900_000_000)
        }
        env.showToast("UX smoke finished", feedback: .success)
    }
}
