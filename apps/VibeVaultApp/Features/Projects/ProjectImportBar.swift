import SwiftUI
import VaultCore

struct ProjectImportBar: View {
    @EnvironmentObject var env: AppEnvironment
    let result: ScanResult
    let projectURL: URL
    let onReview: (ProjectMissingImporter.Result) -> Void

    var body: some View {
        let prefix = SecretNaming.defaultProjectPrefix(from: projectURL)
        let preview = ProjectMissingImporter.collect(
            projectURL: projectURL,
            missing: result.missing,
            includeAllDotenv: true,
            prefix: prefix,
            excludingVaultNames: Set(env.secrets.map(\.name))
        )
        if !preview.previews.isEmpty || !result.missing.isEmpty {
            barContent(previewCount: preview.previews.count, prefix: prefix)
        }
    }

    private func barContent(previewCount: Int, prefix: String) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "tray.and.arrow.down")
                .foregroundStyle(Tokens.Palette.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(previewCount > 0
                     ? "Import \(previewCount) from dotenv files"
                     : "Import \(result.missing.count) missing into vault")
                    .font(.subheadline.weight(.medium))
                Text("Includes .env, .env.local, and nested dotenv files.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            Spacer()
            Button {
                let full = ProjectMissingImporter.collect(
                    projectURL: projectURL,
                    missing: result.missing,
                    includeAllDotenv: true,
                    prefix: prefix
                )
                onReview(full)
            } label: {
                Label("Review import", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(.borderedProminent)
            .tint(Tokens.Palette.accent)
            .disabled(previewCount == 0 && result.missing.isEmpty)
        }
        .padding(Tokens.Space.md)
        .background(Tokens.Palette.accent.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.Palette.accent.opacity(0.2),
                              lineWidth: Tokens.Stroke.hairline)
        )
    }
}
