import SwiftUI
import VaultCore

struct TOTPDetailRow: View {
    let secret: Secret
    let unlockedAuthURL: String?
    let unlock: () -> Void
    let manage: () -> Void
    let copy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(alignment: .center) {
                Label("MFA code", systemImage: "number.square")
                    .foregroundStyle(Tokens.Text.secondary)
                Spacer()
                Button(secret.hasTOTP ? "Manage" : "Add") { manage() }
                    .buttonStyle(.borderless)
            }
            content
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.md)
    }

    @ViewBuilder
    private var content: some View {
        if let unlockedAuthURL {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let code = try? TOTPGenerator.code(from: unlockedAuthURL, at: context.date) {
                    VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                        HStack(spacing: Tokens.Space.md) {
                            Text(grouped(code.code))
                                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                                .textSelection(.enabled)
                            Button {
                                copy(code.code)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                            .help("Copy MFA code")
                            Spacer()
                            Text("\(code.secondsRemaining)s")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Tokens.Text.secondary)
                        }
                        ProgressView(value: Double(code.secondsRemaining), total: Double(code.period))
                            .tint(Tokens.Palette.accent)
                    }
                } else {
                    Text("MFA setup key could not be read.")
                        .font(.caption)
                        .foregroundStyle(Tokens.Status.warning)
                }
            }
        } else if secret.hasTOTP {
            HStack {
                Text("Attached. Unlock to view the current code.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
                Spacer()
                Button("Unlock") { unlock() }
                    .buttonStyle(.bordered)
            }
        } else {
            Text("No rotating code attached.")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
        }
    }

    private func grouped(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }
}
