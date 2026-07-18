import SwiftUI
import VaultCore

struct AIPluginSection: View {
    let manifests: [ProviderPluginManifest]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Provider plugins (coming)").font(.subheadline.weight(.semibold))
            Text("Builtin: Cloudflare, Vercel, PushCI. Third-party manifests load from Application Support.")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
            ForEach(manifests, id: \.id) { m in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(m.displayName).font(.caption.weight(.medium))
                        Text(m.id).font(.caption2).foregroundStyle(Tokens.Text.tertiary)
                    }
                    Spacer()
                    Text(m.version).font(.caption2).foregroundStyle(Tokens.Text.tertiary)
                }
            }
        }
        .padding(Tokens.Space.lg)
        .cardSurface()
    }
}
