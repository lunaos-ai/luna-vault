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
        let strength = generatedStrength
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

    private var generatedStrength: GeneratedStrength {
        let bits: Double
        switch format {
        case .hex:
            bits = Double(length) * 4
        case .base64URL, .base64:
            bits = Double(length) * 6
        case .password:
            bits = Double(length) * log2(75)
        case .uuid:
            bits = 122
        case .prefixedToken:
            let tokenPrefix = "\(SecretValueGenerator.normalizedPrefix(prefix))_"
            bits = Double(max(8, length - tokenPrefix.count)) * 6
        }
        if bits >= 180 {
            return GeneratedStrength(label: "Very strong", color: Tokens.Status.success, detail: "\(Int(bits)) bits estimated entropy")
        }
        if bits >= 96 {
            return GeneratedStrength(label: "Strong", color: Tokens.Palette.mint, detail: "\(Int(bits)) bits estimated entropy")
        }
        return GeneratedStrength(label: "Short", color: Tokens.Status.warning, detail: "\(Int(bits)) bits estimated entropy")
    }
}

private struct GeneratedStrength {
    let label: String
    let color: Color
    let detail: String
}

private enum GeneratorTemplate: String, CaseIterable, Identifiable {
    case providerAPIKey
    case webhookSecret
    case databasePassword
    case humanPassword
    case csrfToken
    case uuid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .providerAPIKey: return "API key"
        case .webhookSecret: return "Webhook"
        case .databasePassword: return "Database"
        case .humanPassword: return "Password"
        case .csrfToken: return "CSRF"
        case .uuid: return "UUID"
        }
    }

    var subtitle: String {
        switch self {
        case .providerAPIKey: return "URL-safe token"
        case .webhookSecret: return "Prefixed token"
        case .databasePassword: return "CLI-safe password"
        case .humanPassword: return "Long app password"
        case .csrfToken: return "Hex secret"
        case .uuid: return "Identifier"
        }
    }

    var systemImage: String {
        switch self {
        case .providerAPIKey: return "key.fill"
        case .webhookSecret: return "point.3.connected.trianglepath.dotted"
        case .databasePassword: return "cylinder.split.1x2"
        case .humanPassword: return "person.badge.key"
        case .csrfToken: return "shield.lefthalf.filled"
        case .uuid: return "number"
        }
    }

    var format: SecretValueFormat {
        switch self {
        case .providerAPIKey: return .base64URL
        case .webhookSecret: return .prefixedToken
        case .databasePassword, .humanPassword: return .password
        case .csrfToken: return .hex
        case .uuid: return .uuid
        }
    }

    var length: Int {
        switch self {
        case .providerAPIKey: return 48
        case .webhookSecret: return 48
        case .databasePassword: return 40
        case .humanPassword: return 28
        case .csrfToken: return 64
        case .uuid: return 36
        }
    }

    var prefix: String {
        switch self {
        case .webhookSecret: return "whsec"
        default: return "vv"
        }
    }
}

private struct GeneratorTemplateButton: View {
    let template: GeneratorTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Image(systemName: template.systemImage)
                        .foregroundStyle(isSelected ? Tokens.Palette.accent : Tokens.Text.secondary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Tokens.Palette.accent)
                    }
                }
                Text(template.title)
                    .font(.subheadline.weight(.semibold))
                Text(template.subtitle)
                    .font(.caption)
                    .foregroundStyle(Tokens.Text.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .padding(Tokens.Space.md)
            .background(
                isSelected ? Tokens.Palette.accent.opacity(0.12) : Tokens.Surface.elevated.opacity(0.65),
                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                    .strokeBorder(
                        isSelected ? Tokens.Palette.accent.opacity(0.5) : Tokens.Surface.separator.opacity(0.5),
                        lineWidth: Tokens.Stroke.hairline
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
