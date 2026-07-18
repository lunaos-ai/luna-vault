import SwiftUI

struct PushciSyncBar: View {
    let projectURL: URL
    var onOpenPushci: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "terminal.fill")
                .foregroundStyle(Tokens.Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("PushCI project")
                    .font(.subheadline.weight(.semibold))
                Text("Sync vault secrets into `.pushci/secrets.enc`")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            Spacer()
            Button("Open PushCI sync", action: onOpenPushci)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(Tokens.Space.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.Surface.separator.opacity(0.6), lineWidth: Tokens.Stroke.hairline)
        )
    }
}
