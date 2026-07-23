import SwiftUI
import VaultCore

struct SecretValueGeneratorSection: View {
    @Binding var value: String
    @State private var format: SecretValueFormat = .base64URL
    @State private var length = SecretValueFormat.base64URL.defaultLength
    @State private var errorMessage: String?

    var body: some View {
        Section {
            Picker("Format", selection: $format) {
                ForEach(SecretValueFormat.allCases) { option in
                    Text(option.label).tag(option)
                }
            }

            if let range = format.lengthRange {
                Stepper("Length \(length)", value: $length, in: range, step: 4)
            } else {
                LabeledContent("Length", value: "\(format.defaultLength)")
            }

            Button {
                generate()
            } label: {
                Label(value.isEmpty ? "Generate value" : "Regenerate value", systemImage: "sparkles")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Generate")
        } footer: {
            Text("Creates a secure random value locally. The generated value is only saved when you press Save.")
        }
        .onChange(of: format) { _, newFormat in
            length = newFormat.clampedLength(length)
            errorMessage = nil
        }
    }

    private func generate() {
        do {
            value = try SecretValueGenerator.generate(format: format, length: length)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
