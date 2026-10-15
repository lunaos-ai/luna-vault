import Foundation

/// Parse, pretty-print, and classify JSON secret values.
public enum SecretJSON {
    public static func parse(_ raw: String) throws -> Any {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SecretError.invalidJSON("empty") }
        guard let data = trimmed.data(using: .utf8) else {
            throw SecretError.invalidJSON("not UTF-8")
        }
        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw SecretError.invalidJSON("malformed")
        }
    }

    public static func looksLikeObjectOrArray(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{" || trimmed.first == "[" else { return false }
        guard let object = try? parse(trimmed) else { return false }
        return object is [String: Any] || object is [Any]
    }

    public static func prettyPrinted(_ raw: String) throws -> String {
        let object = try parse(raw)
        guard object is [String: Any] || object is [Any] else {
            throw SecretError.invalidJSON("JSON secrets must be an object or array")
        }
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        guard let encoded = String(data: data, encoding: .utf8) else {
            throw SecretError.invalidJSON("could not encode")
        }
        return encoded
    }

    public static func compactPrinted(_ raw: String) throws -> String {
        let object = try parse(raw)
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        guard let encoded = String(data: data, encoding: .utf8) else {
            throw SecretError.invalidJSON("could not encode")
        }
        return encoded
    }

    public static func maskedSummary(_ raw: String) -> String {
        guard let object = try? parse(raw) else { return "{…}" }
        if let dict = object as? [String: Any] {
            return dict.count == 1 ? "JSON object · 1 key" : "JSON object · \(dict.count) keys"
        }
        if let array = object as? [Any] {
            return array.count == 1 ? "JSON array · 1 item" : "JSON array · \(array.count) items"
        }
        return "JSON"
    }

    public static func prepared(raw: String, kind: SecretValueKind) throws -> (value: String, kind: SecretValueKind) {
        switch kind {
        case .text:
            return (raw, .text)
        case .json:
            return (try prettyPrinted(raw), .json)
        }
    }
}
