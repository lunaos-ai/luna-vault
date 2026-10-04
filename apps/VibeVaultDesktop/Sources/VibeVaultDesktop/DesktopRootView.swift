import SwiftCrossUI
import VaultCore

struct DesktopRootView: View {
    @Binding var model: DesktopModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            tabBar
            tabContent
            if let error = model.errorMessage {
                Text(error).foregroundColor(.red)
            } else if !model.statusMessage.isEmpty {
                Text(model.statusMessage).foregroundColor(.gray)
            }
        }
        .onAppear { refreshAll() }
    }

    private var header: some View {
        HStack {
            Text("Vibe Vault")
                .font(.system(size: 22, weight: .semibold))
            Spacer()
            Text(PlatformSupport.dataDirectoryHint)
                .foregroundColor(.gray)
                .font(.system(size: 11))
        }
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(DesktopModel.Tab.allCases) { tab in
                Button(tab.rawValue) {
                    model.tab = tab
                    model.clearFeedback()
                }
            }
            Spacer()
            Button("Refresh") { refreshAll() }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch model.tab {
        case .vault:
            VaultPane(model: $model, onRefresh: refreshAll)
        case .projects:
            ProjectsPane(model: $model, onRefresh: refreshProjects)
        case .unlock:
            UnlockPane(model: $model, onRefresh: refreshUnlock)
        case .sync:
            SyncPane(model: $model, onRefresh: refreshAll)
        case .sandbox:
            SandboxPane(model: $model, onRefresh: refreshSandbox)
        case .audit:
            AuditPane(model: $model, onRefresh: refreshAudit)
        case .license:
            LicensePane(model: $model, onRefresh: refreshLicense)
        }
    }

    private func refreshAll() {
        refreshSecrets()
        refreshUnlock()
        refreshLicense()
        refreshSandbox()
        refreshAudit()
        refreshProjects()
    }

    private func refreshProjects() {
        let rows = ProjectRegistry().list()
        if rows.isEmpty {
            model.projectLines = ["No remembered projects. Add a path and scan."]
            return
        }
        model.projectLines = rows.map { row in
            let mark = row.id == ProjectRegistry().selectedID ? "*" : " "
            let health: String
            switch row.access {
            case .ready:
                health = row.missingCount > 0 ? "missing \(row.missingCount)" : "ok"
            case .missing:
                health = "folder missing"
            case .notDirectory:
                health = "not a folder"
            }
            return "\(mark) \(row.name)  \(health)  \(row.path)"
        }
    }

    private func refreshSandbox() {
        let enrolled = DesktopSandbox.isEnrolled()
        if DesktopSandbox.isRunning() {
            model.sandboxStatus = "Running · \(MCPSandboxSettings.endpoint())"
        } else if enrolled {
            model.sandboxStatus = "Passkey enrolled · not listening"
        } else {
            model.sandboxStatus = "No passkey · enroll to start"
        }
    }

    private func refreshAudit() {
        do {
            let events = try AuditDB().query(AuditFilter(limit: 40))
            model.auditLines = events.map { event in
                let time = PlatformDateFormat.logTimestamp(event.timestamp)
                return "\(time)  \(event.action.rawValue)  \(event.secretName)  \(event.agent)"
            }
        } catch {
            model.auditLines = []
        }
    }

    private func refreshSecrets() {
        do {
            model.secretNames = try DesktopVault.service().list().map(\.name).sorted()
            if let selected = model.selectedName,
               let secret = try DesktopVault.service().list().first(where: { $0.name == selected }) {
                model.selectedNotes = secret.notes
                model.selectedMCPAllowed = secret.mcpAllowed
                model.selectedIsJSON = secret.valueKind == .json
            } else if let selected = model.selectedName,
               !model.secretNames.contains(selected) {
                model.selectedName = nil
                model.revealedValue = nil
                model.selectedNotes = nil
            }
            model.errorMessage = nil
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func refreshUnlock() {
        if let status = SharedUnlockSession.status() {
            let mins = Int(status.remainingSeconds() / 60)
            model.unlockRemaining = "Unlocked · \(mins) min left"
        } else if PlatformSupport.hasAppleKeychain {
            model.unlockRemaining = "Touch ID / session gate"
        } else {
            model.unlockRemaining = "Locked - unlock for CLI and reads"
        }
    }

    private func refreshLicense() {
        if let license = TeamEntitlement.current(prefs: DesktopVault.prefs()) {
            model.licenseSummary =
                "\(license.tier) · \(license.seats) seats · \(license.email)"
        } else {
            model.licenseSummary = "Solo (offline Team key optional)"
        }
    }
}
