import AppKit
import SwiftUI
import VaultCore

struct SecretJSONEditor: View {
    @Binding var text: String
    var errorMessage: String?
    var minHeight: CGFloat = 180
    var showsFileLoader = true

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            SecretJSONTextView(text: $text, minHeight: minHeight)
                .frame(height: minHeight)
                .padding(Tokens.Space.xs)
                .background(
                    Tokens.Surface.background.opacity(0.7),
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                        .strokeBorder(Tokens.Surface.separator.opacity(0.7), lineWidth: Tokens.Stroke.hairline)
                )

            HStack(spacing: Tokens.Space.sm) {
                Button("Pretty-print") { prettyPrint() }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if showsFileLoader {
                    Button("Load file…") { loadFile() }
                }
                Spacer()
            }
            .font(.caption)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Tokens.Status.warning)
            }
        }
    }

    private func prettyPrint() {
        guard let pretty = try? SecretJSON.prettyPrinted(text) else { return }
        text = pretty
    }

    private func loadFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json, .text]
        panel.begin { response in
            guard response == .OK, let url = panel.url,
                  let contents = try? String(contentsOf: url, encoding: .utf8) else { return }
            text = contents
        }
    }
}
