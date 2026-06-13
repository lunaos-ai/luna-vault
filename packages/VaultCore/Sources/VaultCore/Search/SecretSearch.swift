import Foundation

/// A single ranked search result: the secret, the field that matched, and its score.
public struct SecretMatch: Equatable, Sendable {
    /// Which field carried the match. Name outranks notes outranks value.
    public enum Field: String, Sendable { case name, notes, value }

    public let secret: Secret
    public let field: Field
    public let score: Int

    public init(secret: Secret, field: Field, score: Int) {
        self.secret = secret
        self.field = field
        self.score = score
    }
}

/// Pure, deterministic ranking of secrets against a free-text query.
///
/// Matches over three fields with descending priority: name, notes, value.
/// An exact name match scores highest, then name prefix, then name substring,
/// then a notes substring, then a value substring. Empty query → no results.
/// Value is matched (so a token fragment finds its secret) but the caller
/// should never render the value itself.
public enum SecretSearch {
    public static func rank(_ secrets: [Secret], query: String, limit: Int = 20) -> [SecretMatch] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }

        let matches = secrets.compactMap { match($0, needle) }
        return Array(
            matches
                .sorted { lhs, rhs in
                    lhs.score != rhs.score ? lhs.score > rhs.score : lhs.secret.name < rhs.secret.name
                }
                .prefix(limit)
        )
    }

    private static func match(_ secret: Secret, _ needle: String) -> SecretMatch? {
        let name = secret.name.lowercased()
        if name == needle { return SecretMatch(secret: secret, field: .name, score: 100) }
        if name.hasPrefix(needle) { return SecretMatch(secret: secret, field: .name, score: 80) }
        if name.contains(needle) { return SecretMatch(secret: secret, field: .name, score: 60) }
        if let notes = secret.notes?.lowercased(), notes.contains(needle) {
            return SecretMatch(secret: secret, field: .notes, score: 40)
        }
        if secret.value.lowercased().contains(needle) {
            return SecretMatch(secret: secret, field: .value, score: 20)
        }
        return nil
    }
}
