import Foundation

struct AuthenticatorIssuer: Identifiable, Hashable {
    let name: String
    let aliases: [String]
    let systemImage: String?
    var id: String { name.lowercased() }

    func matches(_ query: String) -> Bool {
        let needle = Self.normalize(query)
        return ([name] + aliases).contains { Self.normalize($0).contains(needle) }
    }

    static func normalize(_ value: String) -> String {
        String(value.folding(
            options: [.caseInsensitive, .diacriticInsensitive], locale: .current
        ).filter { $0.isLetter || $0.isNumber })
    }
}

enum AuthenticatorIssuerCatalog {
    static let entries: [AuthenticatorIssuer] = [
        .init(name: "1Password", aliases: [], systemImage: "key.horizontal"),
        .init(name: "Amazon Web Services", aliases: ["AWS", "Amazon"], systemImage: "cloud"),
        .init(name: "Apple", aliases: ["iCloud"], systemImage: "apple.logo"),
        .init(name: "Atlassian", aliases: ["Jira", "Confluence"], systemImage: "a.square"),
        .init(name: "Auth0", aliases: [], systemImage: "lock.shield"),
        .init(name: "Bitbucket", aliases: [], systemImage: "shippingbox"),
        .init(name: "Cloudflare", aliases: [], systemImage: "cloud.sun"),
        .init(name: "DigitalOcean", aliases: [], systemImage: "drop"),
        .init(name: "Discord", aliases: [], systemImage: "bubble.left.and.bubble.right"),
        .init(name: "Dropbox", aliases: [], systemImage: "shippingbox"),
        .init(name: "Facebook", aliases: ["Meta"], systemImage: "f.square"),
        .init(name: "GitHub", aliases: [], systemImage: "chevron.left.forwardslash.chevron.right"),
        .init(name: "GitLab", aliases: [], systemImage: "arrow.triangle.branch"),
        .init(name: "Google", aliases: ["Gmail", "Google Cloud"], systemImage: "g.circle"),
        .init(name: "Heroku", aliases: [], systemImage: "h.square"),
        .init(name: "Linear", aliases: [], systemImage: "line.3.horizontal.decrease.circle"),
        .init(name: "Microsoft", aliases: ["Azure", "Office 365", "Outlook"], systemImage: "square.grid.2x2"),
        .init(name: "Notion", aliases: [], systemImage: "n.square"),
        .init(name: "Okta", aliases: [], systemImage: "person.badge.key"),
        .init(name: "PayPal", aliases: [], systemImage: "p.square"),
        .init(name: "Salesforce", aliases: [], systemImage: "cloud"),
        .init(name: "Slack", aliases: [], systemImage: "number"),
        .init(name: "Stripe", aliases: [], systemImage: "creditcard"),
        .init(name: "Twilio", aliases: [], systemImage: "phone.connection"),
        .init(name: "Vercel", aliases: [], systemImage: "triangle"),
        .init(name: "X", aliases: ["Twitter"], systemImage: "xmark")
    ]

    static func resolve(_ name: String) -> AuthenticatorIssuer? {
        let normalized = AuthenticatorIssuer.normalize(name)
        return entries.first { entry in
            ([entry.name] + entry.aliases).contains {
                AuthenticatorIssuer.normalize($0) == normalized
            }
        }
    }

    static func suggestions(
        for query: String, existingIssuers: [String], limit: Int = 6
    ) -> [AuthenticatorIssuer] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        let custom = existingIssuers.map {
            resolve($0) ?? AuthenticatorIssuer(name: $0, aliases: [], systemImage: nil)
        }
        var seen = Set<String>()
        let matches = (custom + entries).filter { $0.matches(needle) }.filter {
            seen.insert($0.id).inserted
        }
        return Array(matches.sorted { rank($0, needle) < rank($1, needle) }.prefix(limit))
    }

    private static func rank(_ issuer: AuthenticatorIssuer, _ query: String) -> String {
        let name = AuthenticatorIssuer.normalize(issuer.name)
        let needle = AuthenticatorIssuer.normalize(query)
        return "\(name.hasPrefix(needle) ? 0 : 1)-\(name)"
    }
}
