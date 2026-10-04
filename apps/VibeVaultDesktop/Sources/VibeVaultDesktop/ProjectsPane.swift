import Foundation
import SwiftCrossUI
import VaultCore

struct ProjectsPane: View {
    @Binding var model: DesktopModel
    var onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projects")
                .font(.system(size: 18, weight: .semibold))
            Text("Remembered folders survive restarts. Scan writes missing/extra counts.")
                .foregroundColor(.gray)
            HStack {
                Text("Path")
                TextField("/path/to/project", text: $model.projectPath)
            }
            HStack(spacing: 8) {
                Button("Remember") { remember() }
                Button("Scan") { scan() }
            }
            ForEach(model.projectLines, id: \.self) { line in
                Text(line).font(.system(size: 12))
            }
            Spacer()
        }
        .padding(8)
        .onAppear { onRefresh() }
    }

    private func remember() {
        let url = URL(fileURLWithPath: model.projectPath.isEmpty
            ? FileManager.default.currentDirectoryPath
            : model.projectPath)
        do {
            try ProjectScanner.validateRoot(url)
            let record = try ProjectRegistry().upsert(url: url)
            model.statusMessage = "Remembered \(record.name)"
            model.errorMessage = nil
            onRefresh()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func scan() {
        let url = URL(fileURLWithPath: model.projectPath.isEmpty
            ? FileManager.default.currentDirectoryPath
            : model.projectPath)
        do {
            let names = try DesktopVault.service().list().map(\.name)
            let result = try ProjectWorkflow.scanAndRemember(projectURL: url, vaultNames: names)
            model.statusMessage =
                "Required \(result.required.count) · missing \(result.missing.count) · extra \(result.extra.count)"
            model.errorMessage = nil
            onRefresh()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}
