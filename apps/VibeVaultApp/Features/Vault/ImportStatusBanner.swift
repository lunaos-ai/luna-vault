import SwiftUI
import VaultCore

struct ImportStatusBanner: View {
    let message: String

  private var isError: Bool { message.hasPrefix("error:") }
    private var isSuccess: Bool {
        message.contains("Imported ") && !isError
    }

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(displayText)
                .font(.subheadline)
                .foregroundStyle(Tokens.Text.primary)
            Spacer()
        }
        .padding(Tokens.Space.md)
        .background(tint.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: Tokens.Stroke.hairline)
        )
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        if isError { return "exclamationmark.triangle.fill" }
        if isSuccess { return "checkmark.circle.fill" }
        return "info.circle.fill"
    }

    private var tint: Color {
        if isError { return Tokens.Status.danger }
        if isSuccess { return Tokens.Status.success }
        return Tokens.Status.info
    }

    private var displayText: String {
        if isError { return String(message.dropFirst("error: ".count)) }
        return message
    }
}
