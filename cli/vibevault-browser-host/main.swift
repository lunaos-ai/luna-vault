import Foundation
import VaultCore

private let maxMessageSize = 128 * 1024

struct BrowserImportRequest: Decodable {
    let type: String
    let name: String?
    let value: String?
    let provider: String?
    let sourceUrl: String?
    let overwrite: Bool?
    let mcpAllowed: Bool?
}

struct BrowserImportResponse: Encodable {
    let ok: Bool
    let name: String?
    let error: String?
    let code: String?
    let version: String?

    static func success(name: String) -> BrowserImportResponse {
        BrowserImportResponse(ok: true, name: name, error: nil, code: nil, version: nil)
    }

    static func pong() -> BrowserImportResponse {
        BrowserImportResponse(ok: true, name: nil, error: nil, code: nil, version: "0.1.0")
    }

    static func failure(_ error: String, code: String = "host_error") -> BrowserImportResponse {
        BrowserImportResponse(ok: false, name: nil, error: error, code: code, version: nil)
    }
}

enum BrowserHostError: Error, CustomStringConvertible {
    case invalidType
    case invalidName
    case invalidValue
    case duplicate(String)
    case oversizedMessage
    case incompleteMessage

    var description: String {
        switch self {
        case .invalidType:
            return "unsupported browser host request"
        case .invalidName:
            return "invalid secret name"
        case .invalidValue:
            return "invalid secret value"
        case .duplicate(let name):
            return "secret '\(name)' already exists"
        case .oversizedMessage:
            return "native message is too large"
        case .incompleteMessage:
            return "incomplete native message"
        }
    }
}

final class NativeMessagingHost {
    private let input: FileHandle
    private let output: FileHandle
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(input: FileHandle = .standardInput, output: FileHandle = .standardOutput) {
        self.input = input
        self.output = output
    }

    func run() -> Int32 {
        do {
            while let message = try readMessage() {
                let response = handle(message)
                try write(response)
            }
            return 0
        } catch {
            fputs("vibevault-browser-host: \(error)\n", stderr)
            return 1
        }
    }

    private func handle(_ data: Data) -> BrowserImportResponse {
        do {
            let request = try decoder.decode(BrowserImportRequest.self, from: data)
            if request.type == "ping" {
                return .pong()
            }
            guard request.type == "save_secret" else { throw BrowserHostError.invalidType }
            let name = try validatedName(request.name)
            let value = try validatedValue(request.value)
            let service = try VaultService.live()
            let notes = importNotes(provider: request.provider, sourceUrl: request.sourceUrl)
            let allowMCP = request.mcpAllowed ?? false

            if request.overwrite == true {
                if try service.store.exists(name: name) {
                    try service.update(name: name, value: value, notes: notes, mcpAllowed: allowMCP)
                } else {
                    try service.add(name: name, value: value, notes: notes, mcpAllowed: allowMCP)
                }
            } else {
                do {
                    try service.add(name: name, value: value, notes: notes, mcpAllowed: allowMCP)
                } catch SecretError.duplicate {
                    throw BrowserHostError.duplicate(name)
                }
            }

            return .success(name: name)
        } catch let error as BrowserHostError {
            return .failure(error.description, code: code(for: error))
        } catch let error as SecretError {
            return .failure(error.description, code: "vault_error")
        } catch {
            return .failure("could not save secret", code: "vault_error")
        }
    }

    private func readMessage() throws -> Data? {
        let lengthBytes = input.readData(ofLength: 4)
        if lengthBytes.isEmpty { return nil }
        guard lengthBytes.count == 4 else { throw BrowserHostError.incompleteMessage }

        let length =
            UInt32(lengthBytes[0])
            | (UInt32(lengthBytes[1]) << 8)
            | (UInt32(lengthBytes[2]) << 16)
            | (UInt32(lengthBytes[3]) << 24)
        guard length <= maxMessageSize else { throw BrowserHostError.oversizedMessage }

        let message = input.readData(ofLength: Int(length))
        guard message.count == Int(length) else { throw BrowserHostError.incompleteMessage }
        return message
    }

    private func write(_ response: BrowserImportResponse) throws {
        let data = try encoder.encode(response)
        var length = UInt32(data.count).littleEndian
        let prefix = withUnsafeBytes(of: &length) { Data($0) }
        output.write(prefix)
        output.write(data)
    }

    private func validatedName(_ value: String?) throws -> String {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty, raw.count <= 256 else {
            throw BrowserHostError.invalidName
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-."))
        guard raw.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw BrowserHostError.invalidName
        }
        return raw
    }

    private func validatedValue(_ value: String?) throws -> String {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty, raw.count <= 16_384 else {
            throw BrowserHostError.invalidValue
        }
        return raw
    }

    private func importNotes(provider: String?, sourceUrl: String?) -> String {
        var parts = ["Imported by Vibe Vault browser extension"]
        if let provider = provider?.trimmingCharacters(in: .whitespacesAndNewlines), !provider.isEmpty {
            parts.append("Provider: \(String(provider.prefix(80)))")
        }
        if let sourceUrl = sourceUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !sourceUrl.isEmpty {
            parts.append("Source: \(String(sourceUrl.prefix(500)))")
        }
        return parts.joined(separator: "\n")
    }

    private func code(for error: BrowserHostError) -> String {
        switch error {
        case .duplicate:
            return "duplicate"
        case .invalidName:
            return "invalid_name"
        case .invalidValue:
            return "invalid_value"
        case .invalidType:
            return "invalid_type"
        case .oversizedMessage:
            return "oversized_message"
        case .incompleteMessage:
            return "incomplete_message"
        }
    }
}

exit(NativeMessagingHost().run())
