import SwiftUI
import VaultCore

struct ProjectScannerResults: View {
    @EnvironmentObject var env: AppEnvironment
    let result: ScanResult
    let projectURL: URL?
    @Binding var filter: ProjectScannerView.ResultFilter
    let onReview: (ProjectMissingImporter.Result) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            summary
            if !result.gitLeaks.isEmpty, let url = projectURL {
                GitLeakBanner(
                    leaks: result.gitLeaks,
                    projectURL: url,
                    onInstallHook: { ProjectScannerActions.installGuard(projectURL: url, env: env) },
                    onFixIgnores: { ProjectScannerActions.fixIgnores(projectURL: url, env: env) }
                )
            }
            if let url = projectURL {
                PrepareCursorBar(projectURL: url) { env.openAIAgents = true }
                ProjectImportBar(result: result, projectURL: url, onReview: onReview)
                CloudflareSyncBar(projectURL: url) { env.openCloudflare = true }
                PushciSyncBar(projectURL: url) { env.openPushci = true }
            }
            if let s = env.importStatus {
                Text(s).font(.caption).foregroundStyle(Tokens.Text.secondary)
            }
            Picker("Filter", selection: $filter) {
                ForEach(ProjectScannerView.ResultFilter.allCases) { f in Text(f.rawValue).tag(f) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            ProjectScanResultCard(result: result, filter: filter, projectURL: projectURL)
        }
    }

    private var summary: some View {
        HStack(spacing: Tokens.Space.xs) {
            Text("\(result.required.count)").font(.headline.weight(.semibold))
            Text("required").foregroundStyle(Tokens.Text.secondary)
            if result.missing.count > 0 {
                Text("·").foregroundStyle(Tokens.Text.tertiary)
                Text("\(result.missing.count) missing").foregroundStyle(Tokens.Status.danger)
            }
            if result.extra.count > 0 {
                Text("·").foregroundStyle(Tokens.Text.tertiary)
                Text("\(result.extra.count) extra").foregroundStyle(Tokens.Status.warning)
            }
            Spacer()
        }
        .font(.subheadline)
    }
}
