import SwiftUI
import VaultCore

/// Inline vault health — counts for overview, not dashboard tiles.
struct VaultHealth {
    let total: Int
    let mcpAllowed: Int
    let expired: Int
    let rotateDue: Int
    let expiringSoon: Int

    init(secrets: [Secret]) {
        total = secrets.count
        mcpAllowed = secrets.filter(\.mcpAllowed).count
        expired = secrets.filter(\.isExpired).count
        rotateDue = secrets.filter(\.isRotationDue).count
        expiringSoon = secrets.filter { s in
            guard let exp = s.expiresAt, !s.isExpired else { return false }
            let days = Calendar.current.dateComponents([.day], from: Date(), to: exp).day ?? 99
            return days < 14
        }.count
    }

    var attentionCount: Int { expired + rotateDue + expiringSoon }

    var summaryLine: String {
        if total == 0 { return "Vault empty" }
        var parts = ["\(total) secret\(total == 1 ? "" : "s")"]
        if mcpAllowed > 0 { parts.append("\(mcpAllowed) AI-allowed") }
        if attentionCount > 0 { parts.append("\(attentionCount) need attention") }
        return parts.joined(separator: " · ")
    }
}
