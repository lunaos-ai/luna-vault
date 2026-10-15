import SwiftUI
import VaultCore

struct ProjectScannerView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var relocatingID: UUID?
    @State private var filter: ResultFilter = .all
    @State private var showImportReview = false
    @State private var importPreview: ProjectMissingImporter.Result?

    enum ResultFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case missing = "Missing"
        case extras = "Extra"
        var id: String { rawValue }
    }

    private var projectURL: URL? {
        env.projects.first(where: { $0.id == env.selectedProjectID })?.resolvedURL()
    }

    private var selectedRecord: ProjectRecord? {
        env.projects.first(where: { $0.id == env.selectedProjectID })
    }

    var body: some View {
        HSplitView {
            ProjectListPane(
                onPick: pickFolder,
                onRelocate: { id in
                    relocatingID = id
                    chooseFolder {
                        env.relocateProject(id: id, to: $0)
                        relocatingID = nil
                    }
                }
            )
            detail
        }
        .background(Tokens.Surface.background)
        .navigationTitle("Projects")
        .onAppear {
            env.reloadProjects(migrate: true)
            if let id = env.selectedProjectID { env.selectProject(id: id) }
        }
        .sheet(isPresented: $showImportReview) { importSheet }
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                hero
                if env.isScanning {
                    scanningRow
                } else if let record = selectedRecord, record.access != .ready {
                    movedHint(record)
                } else if let result = env.scanResult {
                    ProjectScannerResults(
                        result: result,
                        projectURL: projectURL,
                        filter: $filter,
                        onReview: { preview in
                            importPreview = preview
                            showImportReview = true
                        }
                    )
                } else {
                    emptyHint
                }
            }
            .padding(Tokens.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var importSheet: some View {
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
                if let url = projectURL, selectedRecord?.access == .ready {
                    Button { env.scan(projectURL: url) } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(env.isScanning)
                }
                Button { pickFolder() } label: {
                    Label(projectURL == nil ? "Choose project" : "Add",
                          systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.Palette.accent)
            }
        }
        .padding(Tokens.Space.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Surface.separator.opacity(0.6), lineWidth: Tokens.Stroke.hairline)
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
            Text("Remembered projects stay in the list. Missing folders can be relocated.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Tokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.xxxl)
    }

    private func movedHint(_ record: ProjectRecord) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("This folder is missing")
                .font(.headline)
            Text(record.path)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Tokens.Text.secondary)
            Button("Relocate…") { relocatingID = record.id; relocateSelected() }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.Palette.accent)
        }
    }

    private func pickFolder() {
        chooseFolder { env.addAndScan(projectURL: $0) }
    }

    private func relocateSelected() {
        guard let id = relocatingID ?? selectedRecord?.id else { return }
        chooseFolder { env.relocateProject(id: id, to: $0); relocatingID = nil }
    }

    private func chooseFolder(_ onPick: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { resp in
            if resp == .OK, let url = panel.url { onPick(url) }
        }
    }
}
