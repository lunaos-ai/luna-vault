import SwiftCrossUI
import VaultCore

struct LicensePane: View {
    @Binding var model: DesktopModel
    var onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Team license")
                .font(.system(size: 18, weight: .semibold))
            Text(model.licenseSummary)
            Text(
                "Solo includes the full vault. Team is an offline VV1 seat license — not a feature lock."
            )
            .foregroundColor(.gray)
            TextField("VV1.…", text: $model.licenseKey)
            HStack(spacing: 8) {
                Button("Activate") { activate() }
                Button("Deactivate") { deactivate() }
            }
            Spacer()
        }
        .padding(8)
    }

    private func activate() {
        do {
            let license = try LicenseStore.activate(
                model.licenseKey,
                prefs: DesktopVault.prefs()
            )
            model.licenseKey = ""
            model.statusMessage = "Activated \(license.tier) for \(license.email)"
            model.errorMessage = nil
            onRefresh()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func deactivate() {
        LicenseStore.deactivate(prefs: DesktopVault.prefs())
        model.statusMessage = "License cleared — Solo"
        model.errorMessage = nil
        onRefresh()
    }
}
