import SwiftUI
import VaultCore

struct SecretBadgeStrip: View {
    let secret: Secret

    var body: some View {
        if !badges.isEmpty {
            HStack(spacing: 6) { ForEach(badges, id: \.text) { badge($0) } }
        }
    }

    private struct Badge {
        let text: String
        let icon: String
        let tint: Color
    }

    private var badges: [Badge] {
        var out: [Badge] = []
        if secret.isExpired {
            out.append(Badge(text: "Expired", icon: "exclamationmark.triangle.fill", tint: .red))
        } else if let exp = secret.expiresAt {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: exp).day ?? 0
            if days < 14 {
                out.append(Badge(text: "Expires in \(days)d", icon: "clock", tint: .orange))
            }
        }
        if secret.isRotationDue {
            out.append(Badge(text: "Rotate due", icon: "arrow.triangle.2.circlepath", tint: .red))
        }
        if secret.mcpAllowed {
            out.append(Badge(text: "MCP", icon: "sparkles", tint: .purple))
        }
        return out
    }

    private func badge(_ b: Badge) -> some View {
        HStack(spacing: 4) {
            Image(systemName: b.icon)
            Text(b.text)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(b.tint.opacity(0.15), in: Capsule())
        .foregroundStyle(b.tint)
    }
}
