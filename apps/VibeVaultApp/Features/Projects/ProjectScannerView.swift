import SwiftUI
import VaultCore

struct ProjectScannerView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var projectURL: URL?
    @State private var filter: ResultFilter = .all
    @State private var showImportReview = false
    @State private var importPreview: ProjectMissingImporter.Result?

    enum ResultFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case missing = "Missing"
        case extras = "Extra"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                hero
                if env.isScanning {
                    scanningRow
                } else if let result = env.scanResult {
                    summaryLine(result)
                    if !result.gitLeaks.isEmpty {
                        GitLeakBanner(
                            leaks: result.gitLeaks,
                            projectURL: projectURL,
                            onInstallHook: {
                                if let u = projectURL { ProjectScannerActions.installGuard(projectURL: u, env: env) }
                            },
                            onFixIgnores: {
                                if let u = projectURL { ProjectScannerActions.fixIgnores(projectURL: u, env: env) }
                            }
                        )
                    }
                    if let url = projectURL {
                        PrepareCursorBar(projectURL: url) { env.openAIAgents = true }
                        ProjectImportBar(result: result, projectURL: url) { preview in
                            importPreview = preview
                            showImportReview = true
                        }
                        CloudflareSyncBar(projectURL: url) { env.openCloudflare = true }
                        PushciSyncBar(projectURL: url) { env.openPushci = true }
                    }
                    if let s = env.importStatus {
                        Text(s).font(.caption).foregroundStyle(Tokens.Text.secondary)
                    }
                    filterPicker
                    ProjectScanResultCard(
                        result: result,
                        filter: filter,
                        projectURL: projectURL
                    )
                } else {
                    emptyHint
                }
            }
            .padding(Tokens.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Tokens.Surface.background)
        .navigationTitle("Projects")
        .sheet(isPresented: $showImportReview) {
            if let url = projectURL, let preview = importPreview {
                ImportReviewSheet(
                    subtitle: url.lastPathComponent,
                    rows: preview.previews.map {
                        ImportRowState(sourceName: $0.sourceName, value: $0.value, sourceFile: $0.sourceFile)
                    },
                    projectURL: url,
                    showPrefix: true,
                    sourceColumnTitle: "Project name",
                    stillMissing: preview.stillMissing,
                    notes: "imported from project dotenv"
                )
                .environmentObject(env)
            }
        }
    }

    private var hero: some View {
        HStack(spacing: Tokens.Space.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .fill(Tokens.Palette.accent.opacity(0.12))
                Image(systemName: "folder.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Tokens.Palette.accent)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(projectURL?.lastPathComponent ?? "Project scanner")
                    .font(.system(.title2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Tokens.Text.primary)
                Text(projectURL?.path ?? "Pick a folder to inspect required secrets.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Tokens.Text.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            HStack(spacing: Tokens.Space.sm) {
                if projectURL != nil {
                    Button { if let u = projectURL { env.scan(projectURL: u) } } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(env.isScanning)
                }
                Button { pickFolder() } label: {
                    Label(projectURL == nil ? "Choose project" : "Change",
                          systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.Palette.accent)
            }
        }
        .padding(Tokens.Space.lg)
        .background(.regularMaterial,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Surface.separator.opacity(0.6),
                              lineWidth: Tokens.Stroke.hairline)
        )
    }

    private var scanningRow: some View {
        HStack(spacing: Tokens.Space.sm) {
            ProgressView().controlSize(.small)
            Text("Scanning project").foregroundStyle(Tokens.Text.secondary)
            Spacer()
        }
        .font(.subheadline)
    }

    private var emptyHint: some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Tokens.Text.tertiary)
            Text("Pick a project folder")
                .font(.headline)
                .foregroundStyle(Tokens.Text.primary)
            Text("Reads wrangler.toml, vercel.json, .env, .env.local, package.json.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Tokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.xxxl)
    }

    private func summaryLine(_ result: ScanResult) -> some View {
        HStack(spacing: Tokens.Space.xs) {
            Text("\(result.required.count)").font(.headline.weight(.semibold))
            Text("required").foregroundStyle(Tokens.Text.secondary)
            if result.missing.count > 0 {
                bullet
                Text("\(result.missing.count) missing").foregroundStyle(Tokens.Status.danger)
            }
            if result.extra.count > 0 {
                bullet
                Text("\(result.extra.count) extra").foregroundStyle(Tokens.Status.warning)
            }
            Spacer()
        }
        .font(.subheadline)
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $filter) {
            ForEach(ResultFilter.allCases) { f in Text(f.rawValue).tag(f) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var bullet: some View {
        Text("·").foregroundStyle(Tokens.Text.tertiary)
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
}
