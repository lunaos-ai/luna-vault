import SwiftUI
import VaultCore

struct MenuBarScene: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                Image(systemName: "key.viewfinder")
                    .foregroundStyle(Tokens.Color.primary)
                Text("luna-vault").font(.headline)
                Spacer()
                Text("\(env.secrets.count) secrets")
                    .font(.caption)
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
            Divider()
            if env.secrets.isEmpty {
                Text("No secrets yet.")
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .padding(.vertical, Tokens.Space.sm)
            } else {
                ForEach(env.secrets.prefix(5)) { secret in
                    HStack {
                        Text(secret.name).font(.system(.body, design: .monospaced))
                        Spacer()
                        Text(secret.maskedValue)
                            .foregroundStyle(Tokens.Color.textSecondary)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                if env.secrets.count > 5 {
                    Text("+ \(env.secrets.count - 5) more…")
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .font(.caption)
                }
            }
            Divider()
            Button("Open luna-vault…") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.borderless)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
        }
        .padding(Tokens.Space.md)
        .frame(width: 280)
        .task { env.refresh() }
    }
}

extension Secret: Identifiable {
    public var id: String { name }
}
