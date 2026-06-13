import AppKit
import SwiftUI
import VaultCore

/// Export one or more secrets to a project `.env` file, with an optional git
/// guard (`.gitignore` entry + pre-commit hook) so they aren't committed.
struct EnvExportView: View {
    @EnvironmentObject var env: AppEnvironment
    let names: [String]
    @Binding var isPresented: Bool
    @State private var overwrite = false
    @State private var addGuard = true
    @State private var status: String?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Export to .env").font(.title2.weight(.semibold))
                Text("\(names.count) secret\(names.count == 1 ? "" : "s") → a project .env file")
                    .font(.callout).foregroundStyle(Tokens.Text.secondary)
            }

            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Toggle("Overwrite file (don't merge existing keys)", isOn: $overwrite)
                Toggle("Add git guard (.gitignore + pre-commit hook)", isOn: $addGuard)
            }
            .toggleStyle(.switch)
            .glassPanel(radius: Tokens.Radius.md)
            .padding(Tokens.Space.md)

            if let status {
                Text(status)
                    .font(.callout).foregroundStyle(Tokens.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            HStack {
                Button("Cancel") { isPresented = false }.buttonStyle(.glass)
                Spacer()
                Button { Task { await choose() } } label: {
                    Label("Choose file & export…", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.glassProminent)
                .disabled(busy || names.isEmpty)
            }
        }
        .padding(Tokens.Space.xxl)
        .frame(width: 460, height: 360)
        .background(LiquidBackdrop())
    }

    @MainActor
    private func choose() async {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = ".env"
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        panel.message = "Choose where to write the .env file"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        busy = true; defer { busy = false }
        status = await env.exportEnv(
            to: url, names: names,
            mode: overwrite ? .overwrite : .merge,
            addGuard: addGuard
        )
    }
}
