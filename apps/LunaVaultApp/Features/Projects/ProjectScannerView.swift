import SwiftUI
import VaultCore

struct ProjectScannerView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var projectURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            HStack {
                Text("Project scanner").font(.title2.bold())
                Spacer()
                Button {
                    pickFolder()
                } label: {
                    Label("Choose project…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.Color.primary)
            }

            if let url = projectURL {
                Text(url.path).font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Tokens.Color.textSecondary)
            } else {
                Text("Pick a project folder to scan for required secrets.")
                    .foregroundStyle(Tokens.Color.textSecondary)
            }

            if let result = env.scanResult {
                scanResultView(result)
            }
            Spacer()
        }
        .padding(Tokens.Space.xl)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { resp in
            if resp == .OK, let url = panel.url {
                projectURL = url
                env.scan(projectURL: url)
            }
        }
    }

    @ViewBuilder
    private func scanResultView(_ result: ScanResult) -> some View {
        HStack(spacing: Tokens.Space.md) {
            statTile("Required", count: result.required.count, tint: Tokens.Color.primary)
            statTile("Missing", count: result.missing.count, tint: Tokens.Color.danger)
            statTile("Extra", count: result.extra.count, tint: Tokens.Color.warning)
        }
        if !result.missing.isEmpty {
            sectionList(title: "Missing", items: Array(result.missing).sorted(), tint: Tokens.Color.danger)
        }
        if !result.extra.isEmpty {
            sectionList(title: "Extra (in vault, not in project)", items: Array(result.extra).sorted(), tint: Tokens.Color.warning)
        }
    }

    private func statTile(_ label: String, count: Int, tint: Color) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption).foregroundStyle(Tokens.Color.textSecondary)
            Text("\(count)").font(.system(size: 32, weight: .bold)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func sectionList(title: String, items: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(title).font(.headline).foregroundStyle(tint)
            ForEach(items, id: \.self) { name in
                Text(name).font(.system(.body, design: .monospaced))
            }
        }
        .cardSurface()
    }
}
