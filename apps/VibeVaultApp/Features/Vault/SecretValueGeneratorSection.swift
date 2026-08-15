import AppKit
import SwiftUI
import VaultCore

struct SecretValueGeneratorSection: View {
    @EnvironmentObject var env: AppEnvironment
    @Binding var value: String
    @State private var format: SecretValueFormat = .base64URL
    @State private var length = SecretValueFormat.base64URL.defaultLength
    @State private var prefix = "vv"
    @State private var selectedTemplate: GeneratorTemplate = .providerAPIKey
    @State private var revealDraft = false
    @State private var copiedDraft = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 148), spacing: Tokens.Space.sm)],
                    alignment: .leading,
                    spacing: Tokens.Space.sm
                ) {
                    ForEach(GeneratorTemplate.allCases) { template in
                        GeneratorTemplateButton(
                            template: template,
                            isSelected: selectedTemplate == template,
                            action: { apply(template) }
                        )
                    }
                }

                Picker("Format", selection: $format) {
                    ForEach(SecretValueFormat.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }

                if format == .prefixedToken {
                    TextField("Prefix", text: $prefix, prompt: Text("vv"))
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                }

                lengthControl

                if !value.isEmpty {
                    generatedDraft
                }

                HStack(spacing: Tokens.Space.sm) {
                    Button {
                        generate()
                    } label: {
                        Label(value.isEmpty ? "Generate value" : "Regenerate value", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        copyDraft()
                    } label: {
                        Label(copiedDraft ? "Copied" : "Copy draft", systemImage: copiedDraft ? "checkmark" : "doc.on.doc")
                    }
                    .disabled(value.isEmpty)

                    Button {
                        value = ""
                        revealDraft = false
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .disabled(value.isEmpty)

                    Spacer()

                    strengthPill
                }
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
        .onChange(of: value) { _, _ in
            copiedDraft = false
        }
    }

    @ViewBuilder
    private var lengthControl: some View {
        if let range = format.lengthRange {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                HStack {
                    Text("Length")
                    Spacer()
                    Text("\(length)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Tokens.Text.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(length) },
                        set: { length = format.clampedLength(Int($0.rounded())) }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: 4
                )
                Stepper("Adjust length", value: $length, in: range, step: 4)
                    .labelsHidden()
            }
        } else {
            LabeledContent("Length", value: "\(format.defaultLength)")
        }
    }

    private var generatedDraft: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "key.horizontal")
                .foregroundStyle(Tokens.Palette.accent)
            Text(revealDraft ? value : SecretNaming.maskedValue(value))
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                revealDraft.toggle()
            } label: {
                Image(systemName: revealDraft ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .help(revealDraft ? "Hide generated draft" : "Reveal generated draft")
            Button {
                copyDraft()
            } label: {
                Image(systemName: copiedDraft ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copiedDraft ? Tokens.Status.success : Tokens.Text.secondary)
            }
            .buttonStyle(.borderless)
            .help("Copy generated draft")
        }
        .padding(Tokens.Space.md)
        .deepInset(radius: Tokens.Radius.sm)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: copyDraft)
        .help("Double-click to copy generated draft")
    }

    private var strengthPill: some View {
        let strength = Self.generatedStrength(format: format, length: length, prefix: prefix)
        return HStack(spacing: Tokens.Space.xs) {
            Circle()
                .fill(strength.color)
                .frame(width: 7, height: 7)
            Text(strength.label)
                .font(.caption.weight(.semibold))
        }
        .tintedChip(strength.color)
        .help(strength.detail)
    }

    private func generate() {
        do {
            value = try SecretValueGenerator.generate(
                format: format,
                length: length,
                prefix: format == .prefixedToken ? prefix : nil
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ template: GeneratorTemplate) {
        selectedTemplate = template
        format = template.format
        length = template.format.clampedLength(template.length)
        prefix = template.prefix
        errorMessage = nil
        generate()
    }

    private func copyDraft() {
        guard !value.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copiedDraft = true
        env.showToast("Copied generated draft")
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run { copiedDraft = false }
        }
    }
}
