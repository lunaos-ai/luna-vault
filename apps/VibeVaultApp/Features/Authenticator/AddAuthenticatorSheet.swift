import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VaultCore

struct AddAuthenticatorSheet: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.dismiss) var dismiss
    @State var input = ""
    @State var issuer = ""
    @State var accountName = ""
    @State var parsed: TOTPAccount?
    @State var errorText: String?
    @State var decodedPayloads: [String] = []
    @State var selectedPayload = 0
    @State var saving = false
    @State var showCamera = false
    @State var dropTargeted = false

    init(initialInput: String? = nil) {
        _input = State(initialValue: initialInput ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            Text("Add verification code").font(.title2.weight(.semibold))
            if parsed == nil { enrollmentForm } else { reviewStep }
            footer
        }
        .padding(Tokens.Space.xl)
        .frame(width: 540)
        .sheet(isPresented: $showCamera) {
            LiveQRCodeScannerSheet { applyPayload($0) }
        }
        .onAppear {
            if !input.isEmpty { applyPayload(input, reportFailure: false) }
        }
        .onDisappear { clearSensitiveState() }
    }

    private var enrollmentForm: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.sm) {
                sourceButton("Scan QR", icon: "camera.viewfinder") { showCamera = true }
                sourceButton("Choose Image", icon: "photo") { chooseImage() }
                sourceButton("Paste", icon: "doc.on.clipboard") { pasteClipboard() }
            }
            dropTarget
            SecureField("Setup key or otpauth URL", text: $input)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Setup key or otpauth URL")
            IssuerSuggestionField(
                text: $issuer,
                existingIssuers: env.authenticatorAccounts.map(\.issuer)
            )
            TextField("Account name", text: $accountName)
                .textFieldStyle(.roundedBorder)
            if decodedPayloads.count > 1 { payloadPicker }
            if let errorText {
                Label(errorText, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(Tokens.Status.danger)
            }
            Text("QR images are decoded on this Mac and are never uploaded.")
                .font(.caption)
                .foregroundStyle(Tokens.Text.secondary)
        }
    }

    private var dropTarget: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "qrcode.viewfinder")
                .font(.title3)
                .foregroundStyle(dropTargeted ? Tokens.Palette.accent : Tokens.Text.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Drop a QR image").font(.body.weight(.medium))
                Text("Screenshot, PNG, JPEG, or copied image")
                    .font(.caption).foregroundStyle(Tokens.Text.secondary)
            }
            Spacer()
        }
        .padding(Tokens.Space.md)
        .background(Tokens.Surface.elevated, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                .stroke(
                    dropTargeted ? Tokens.Palette.accent : Tokens.Surface.separator.opacity(0.7),
                    lineWidth: dropTargeted ? 1 : 0.5
                )
        }
        .onDrop(
            of: [UTType.image.identifier, UTType.fileURL.identifier, UTType.plainText.identifier],
            isTargeted: $dropTargeted,
            perform: handleDrop
        )
        .accessibilityLabel("Drop authenticator QR image")
    }

    private var payloadPicker: some View {
        Picker("QR code", selection: $selectedPayload) {
            ForEach(decodedPayloads.indices, id: \.self) {
                Text("QR code \($0 + 1)").tag($0)
            }
        }
        .onChange(of: selectedPayload) { _, value in applyPayload(decodedPayloads[value]) }
    }

    private var reviewStep: some View {
        VStack(spacing: 0) {
            HStack(spacing: Tokens.Space.sm) {
                IssuerIcon(name: issuer, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(issuer).font(.headline)
                    Text(accountName).font(.caption).foregroundStyle(Tokens.Text.secondary)
                }
                Spacer()
            }
            .padding(Tokens.Space.md)
            Divider()
            reviewRow("Algorithm", parsed?.algorithm.rawValue.uppercased() ?? "")
            Divider()
            reviewRow("Digits", "\(parsed?.digits ?? 6)")
            Divider()
            reviewRow("Period", "\(parsed?.period ?? 30) seconds")
            if let parsed, let code = try? TOTPGenerator.code(for: parsed) {
                Divider()
                reviewRow("Test code", grouped(code.code))
            }
        }
        .background(Tokens.Surface.elevated, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }

    private var footer: some View {
        HStack {
            Button("Cancel", role: .cancel) { clearAndDismiss() }
            Spacer()
            if parsed == nil {
                Button("Review") { review() }
                    .buttonStyle(.borderedProminent)
                    .disabled(input.isEmpty || issuer.isEmpty || accountName.isEmpty)
            } else {
                Button("Back") { parsed = nil }
                Button("Save") { Task { await save() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(saving)
            }
        }
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value) }
            .padding(Tokens.Space.md)
    }
}
