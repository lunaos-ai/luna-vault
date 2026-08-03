import SwiftUI

struct PushciSyncBar: View {
    let projectURL: URL
    var onOpenPushci: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Space.md) {
            Image(systemName: "cloud.fill")
                .foregroundStyle(Tokens.Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("PushCI").font(.subheadline.weight(.semibold))
                Text("Onboard vault secrets to a cloud project or local store")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
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
