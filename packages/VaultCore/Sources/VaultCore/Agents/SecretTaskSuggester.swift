import Foundation

/// Suggests secret *names* for a task description using project scan + vault (values never returned).
public enum SecretTaskSuggester {
    public static func suggest(
        task: String,
        scan: ScanResult,
        vaultNames: Set<String>
    ) -> SuggestedSecrets {
        let tokens = tokenize(task)
        let scored = score(required: scan.required.union(scan.missing), tokens: tokens)
        let ranked = scored.sorted { $0.score > $1.score }.map(\.name)
        let likely = ranked.isEmpty ? Array(scan.required).sorted() : ranked
        let inVault = likely.filter { vaultNames.contains($0) }
        let missing = likely.filter { !vaultNames.contains($0) }
        return SuggestedSecrets(likely: likely, presentInVault: inVault, missingFromVault: missing)
    }

    public struct SuggestedSecrets: Equatable, Sendable {
        public let likely: [String]
        public let presentInVault: [String]
        public let missingFromVault: [String]

        public init(likely: [String], presentInVault: [String], missingFromVault: [String]) {
            self.likely = likely
            self.presentInVault = presentInVault
            self.missingFromVault = missingFromVault
        }
    }

    private struct Scored { let name: String; let score: Int }

    private static func tokenize(_ text: String) -> Set<String> {
        let upper = text.uppercased()
        let parts = upper.split { !$0.isLetter && !$0.isNumber && $0 != "_" }
        return Set(parts.map(String.init).filter { $0.count >= 2 })
    }

    private static func score(required: Set<String>, tokens: Set<String>) -> [Scored] {
        required.map { name in
            var s = 0
            let parts = name.uppercased().split(separator: "_").map(String.init)
            for p in parts where tokens.contains(p) { s += 3 }
            for t in tokens where name.uppercased().contains(t) { s += 1 }
            // Domain heuristics
            if tokens.contains("CLOUDFLARE") || tokens.contains("WRANGLER"),
               name.contains("CF_") || name.contains("CLOUDFLARE") { s += 4 }
            if tokens.contains("VERCEL"), name.contains("VERCEL") { s += 4 }
            if tokens.contains("STRIPE"), name.contains("STRIPE") { s += 4 }
            if tokens.contains("DATABASE") || tokens.contains("POSTGRES"),
               name.contains("DATABASE") || name.contains("DB_") { s += 4 }
            return Scored(name: name, score: s)
        }.filter { $0.score > 0 }
    }
}
