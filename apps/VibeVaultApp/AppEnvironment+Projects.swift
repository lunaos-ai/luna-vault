import Foundation
import VaultCore

extension AppEnvironment {
    func reloadProjects(migrate: Bool = false) {
        let registry = ProjectRegistry()
        if migrate {
            try? registry.migratePrefixPaths(settings.projectPrefixes)
        }
        projects = registry.list()
        selectedProjectID = registry.selectedID ?? projects.first?.id
    }

    func addAndScan(projectURL: URL) {
        do {
            let record = try ProjectRegistry().upsert(url: projectURL, prefix: projectPrefix(for: projectURL))
            selectedProjectID = record.id
            scan(projectURL: record.resolvedURL())
            reloadProjects()
        } catch {
            lastError = "\(error)"
        }
    }

    func selectProject(id: UUID) {
        selectedProjectID = id
        try? ProjectRegistry().select(id: id)
        guard let record = projects.first(where: { $0.id == id }) else { return }
        let url = record.resolvedURL()
        switch record.access {
        case .ready:
            scan(projectURL: url)
        case .missing:
            lastError = "Project folder moved or deleted: \(record.path)"
            scanResult = nil
        case .notDirectory:
            lastError = "Not a folder: \(record.path)"
            scanResult = nil
        }
    }

    func forgetProject(id: UUID) {
        try? ProjectRegistry().remove(id: id)
        if selectedProjectID == id {
            scanResult = nil
            lastScannedURL = nil
        }
        reloadProjects()
    }

    func relocateProject(id: UUID, to url: URL) {
        do {
            let record = try ProjectRegistry().relocate(id: id, to: url)
            selectedProjectID = record.id
            reloadProjects()
            scan(projectURL: record.resolvedURL())
        } catch {
            lastError = "\(error)"
        }
    }
}
