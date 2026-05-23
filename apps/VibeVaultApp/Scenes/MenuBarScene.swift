import SwiftUI
import VaultCore

struct MenuBarScene: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "key.viewfinder")
                    .foregroundStyle(.tint)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Vibe Vault").font(.headline)
                    Text("\(env.secrets.count) secret\(env.secrets.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            if env.secrets.isEmpty {
                HStack {
                    Image(systemName: "tray").foregroundStyle(.secondary)
                    Text("No secrets yet")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(env.secrets.prefix(5)) { secret in
                    HStack {
                        Text(secret.name)
                            .font(.system(.callout, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        if secret.isExpired || secret.isRotationDue {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        Text(secret.maskedValue)
                            .foregroundStyle(.secondary)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                if env.secrets.count > 5 {
                    Text("+ \(env.secrets.count - 5) more…")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            Divider()

            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Vibe Vault…", systemImage: "macwindow")
            }
            .buttonStyle(.borderless)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 300)
        .task { env.refresh() }
    }
}

extension Secret: Identifiable {
    public var id: String { name }
}
