import Foundation
#if canImport(Vision)
import Vision
#endif

public enum ImageCredentialImporter {
    public static func recognizeFile(at url: URL) throws -> [VaultService.ImportItem] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImporterError.fileNotFound(url.path)
        }
        #if canImport(Vision)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        let handler = VNImageRequestHandler(url: url)
        try handler.perform([request])
        let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        return parseRecognizedText(text, source: url.lastPathComponent)
        #else
        throw ImporterError.invalidSource("image OCR requires Vision on macOS")
        #endif
    }

    public static func parseRecognizedText(_ text: String, source: String? = nil) -> [VaultService.ImportItem] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }

        let prefix = providerPrefix(text: text, source: source)
        let notes = source.map { "imported from image OCR: \($0)" } ?? "imported from image OCR"
        var imported: [VaultService.ImportItem] = []
        var seen = Set<String>()

        for (index, line) in lines.enumerated() {
            guard let label = credentialLabel(in: line) else { continue }
            let value = valueInSameLine(line, label: label.displayName)
                ?? nextValue(after: index, in: lines)
            guard let value else { continue }
            let name = SecretNaming.applyPrefix(prefix, to: label.vaultSuffix)
            guard seen.insert(name).inserted else { continue }
            imported.append(VaultService.ImportItem(name: name, value: value, notes: notes))
        }
        return imported
    }

    private struct CredentialLabel {
        let displayName: String
        let vaultSuffix: String
    }

    private static let credentialLabels = [
        CredentialLabel(displayName: "client secret", vaultSuffix: "CLIENT_SECRET"),
        CredentialLabel(displayName: "signing secret", vaultSuffix: "SIGNING_SECRET"),
        CredentialLabel(displayName: "verification token", vaultSuffix: "VERIFICATION_TOKEN"),
        CredentialLabel(displayName: "access token", vaultSuffix: "ACCESS_TOKEN"),
        CredentialLabel(displayName: "refresh token", vaultSuffix: "REFRESH_TOKEN"),
        CredentialLabel(displayName: "api key", vaultSuffix: "API_KEY"),
        CredentialLabel(displayName: "secret key", vaultSuffix: "SECRET_KEY"),
        CredentialLabel(displayName: "client id", vaultSuffix: "CLIENT_ID"),
        CredentialLabel(displayName: "app id", vaultSuffix: "APP_ID"),
        CredentialLabel(displayName: "token", vaultSuffix: "TOKEN"),
        CredentialLabel(displayName: "password", vaultSuffix: "PASSWORD")
    ]

    private static func credentialLabel(in line: String) -> CredentialLabel? {
        let normalized = normalizedText(line)
        if normalized.contains("date of") || normalized.contains("creation") {
            return nil
        }
        return credentialLabels.first { containsLabel($0.displayName, in: normalized) }
    }

    private static func containsLabel(_ label: String, in normalizedLine: String) -> Bool {
        let pattern = #"(^|\b)"# + NSRegularExpression.escapedPattern(for: label) + #"(\b|$)"#
        return normalizedLine.range(of: pattern, options: .regularExpression) != nil
    }

    private static func valueInSameLine(_ line: String, label: String) -> String? {
        guard let range = line.lowercased().range(of: label) else { return nil }
        return firstCredentialToken(in: String(line[range.upperBound...]))
    }

    private static func nextValue(after index: Int, in lines: [String]) -> String? {
        guard index + 1 < lines.count else { return nil }
        for next in lines[(index + 1)..<min(index + 4, lines.count)] {
            if credentialLabel(in: next) != nil { return nil }
            if let value = firstCredentialToken(in: next) { return value }
        }
        return nil
    }

    private static func firstCredentialToken(in text: String) -> String? {
        let stripped = text
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "=", with: " ")
        let tokens = stripped
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        for token in tokens {
            let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`()[]{}<>.,;"))
            if isCredentialValue(cleaned) { return cleaned }
        }
        return nil
    }

    private static func isCredentialValue(_ value: String) -> Bool {
        let lower = value.lowercased()
        let banned: Set<String> = [
            "show", "regenerate", "copy", "hide", "secret", "token", "password", "key", "credentials"
        ]
        guard value.count >= 4, value.count <= 512, !banned.contains(lower) else { return false }
        if value.range(of: #"^\d{1,2}/\d{1,2}/\d{2,4}$"#, options: .regularExpression) != nil { return false }
        if value.range(of: #"^[A-Z][a-z]+$"#, options: .regularExpression) != nil { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._~+/=-"))
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func providerPrefix(text: String, source: String?) -> String {
        let lower = text.lowercased()
        let known: [(String, String)] = [
            ("slack", "SLACK"),
            ("google ai studio", "GEMINI"),
            ("gemini", "GEMINI"),
            ("openai", "OPENAI"),
            ("anthropic", "ANTHROPIC"),
            ("github", "GITHUB"),
            ("stripe", "STRIPE"),
            ("cloudflare", "CLOUDFLARE"),
            ("vercel", "VERCEL")
        ]
        if let match = known.first(where: { lower.contains($0.0) }) {
            return match.1
        }
        if let source {
            let base = URL(fileURLWithPath: source).deletingPathExtension().lastPathComponent
            let spaced = base.replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
            let sanitized = SecretNaming.sanitizePrefix(spaced)
            if !sanitized.isEmpty { return sanitized }
        }
        return "IMAGE"
    }

    private static func normalizedText(_ line: String) -> String {
        line.lowercased()
            .replacingOccurrences(of: #"[_\-.]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}
