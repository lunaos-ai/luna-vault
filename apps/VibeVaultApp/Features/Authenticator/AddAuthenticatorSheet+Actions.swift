import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VaultCore

extension AddAuthenticatorSheet {
    func sourceButton(
        _ title: String, icon: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { Label(title, systemImage: icon) }
            .buttonStyle(.bordered)
            .accessibilityLabel(title)
    }

    func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Choose an authenticator QR image."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        decodeImage(at: url)
    }

    func pasteClipboard() {
        let board = NSPasteboard.general
        if let value = board.string(forType: .string) {
            applyPayload(value)
        } else if let image = NSImage(pasteboard: board), let data = image.tiffRepresentation {
            decodeImage(data)
        } else {
            errorText = "Clipboard does not contain a setup URL or QR image."
        }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data else { return }
                Task { @MainActor in decodeImage(data) }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data,
                      let raw = String(data: data, encoding: .utf8),
                      let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                Task { @MainActor in decodeImage(at: url) }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
                guard let data, let value = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in applyPayload(value) }
            }
            return true
        }
        return false
    }

    func decodeImage(at url: URL) {
        do { acceptDecoded(try TOTPQRCodeDecoder.payloads(in: url)) }
        catch { errorText = "\(error)" }
    }

    func decodeImage(_ data: Data) {
        do { acceptDecoded(try TOTPQRCodeDecoder.payloads(in: data)) }
        catch { errorText = "\(error)" }
    }

    func acceptDecoded(_ payloads: [String]) {
        decodedPayloads = payloads
        selectedPayload = 0
        applyPayload(payloads[0])
    }

    func applyPayload(_ payload: String, reportFailure: Bool = true) {
        do {
            let account = try TOTPGenerator.account(from: payload)
            input = payload
            if let value = account.issuer, !value.isEmpty { issuer = value }
            if let value = account.account, !value.isEmpty { accountName = value }
            errorText = nil
        } catch {
            if reportFailure { errorText = "QR code does not contain a valid authenticator setup." }
        }
    }

    func review() {
        do {
            let value = try TOTPGenerator.account(from: input)
            guard !issuer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AuthenticatorError.invalidIdentity
            }
            parsed = value
            errorText = nil
        } catch { errorText = "\(error)" }
    }

    func save() async {
        saving = true
        if await env.addAuthenticator(input: input, issuer: issuer, accountName: accountName) {
            clearAndDismiss()
        }
        saving = false
    }

    func clearAndDismiss() { clearSensitiveState(); dismiss() }

    func clearSensitiveState() {
        input = ""; issuer = ""; accountName = ""; parsed = nil
        decodedPayloads = []; errorText = nil; selectedPayload = 0
    }

    func grouped(_ code: String) -> String {
        let middle = code.index(code.startIndex, offsetBy: code.count / 2)
        return "\(code[..<middle]) \(code[middle...])"
    }
}
