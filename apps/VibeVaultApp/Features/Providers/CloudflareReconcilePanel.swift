import SwiftUI
import VaultCore

struct CloudflareReconcilePanel: View {
    let reconcile: CloudflareReconcile
    @Binding var selectedWorkerNames: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.lg) {
                metric("In sync", reconcile.inSync.count, Tokens.Status.success)
                metric("To push", reconcile.extraLocally.count, Tokens.Palette.accent)
                metric("Remote only", reconcile.missingLocally.count, Tokens.Status.warning)
            }
            if !reconcile.extraLocally.isEmpty {
                secretList(
                    title: "Vault secrets not on Workers",
                    names: reconcile.extraLocally,
                    selectable: true
                )
            }
            if !reconcile.missingLocally.isEmpty {
                secretList(
                    title: "On Workers but not in vault (values not readable)",
                    names: reconcile.missingLocally,
                    selectable: false
                )
            }
            if reconcile.extraLocally.isEmpty && reconcile.missingLocally.isEmpty && !reconcile.inSync.isEmpty {
                Label("All \(reconcile.inSync.count) secrets match", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Tokens.Status.success)
            }
        }
        .padding(Tokens.Space.lg)
        .cardSurface()
    }

    private func metric(_ label: String, _ count: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(count)").font(.title2.weight(.semibold)).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(Tokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func secretList(title: String, names: Set<String>, selectable: Bool) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(title).font(.subheadline.weight(.semibold))
            ForEach(names.sorted(), id: \.self) { name in
                HStack {
                    if selectable {
                        Toggle(isOn: binding(for: name)) {
                            Text(name).font(.system(.body, design: .monospaced))
                        }
                    } else {
                        Image(systemName: "cloud")
                            .foregroundStyle(Tokens.Text.tertiary)
                        Text(name).font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
    }

    private func binding(for workerName: String) -> Binding<Bool> {
        Binding(
            get: { selectedWorkerNames.contains(workerName) },
            set: { on in
                if on { selectedWorkerNames.insert(workerName) }
                else { selectedWorkerNames.remove(workerName) }
            }
        )
    }
}
