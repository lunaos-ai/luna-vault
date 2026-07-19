import SwiftUI
import VaultCore

enum VaultListFilter: String, CaseIterable, Identifiable {
    case all, expiring, rotateDue = "rotate", mcp
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .expiring: return "Expiring"
        case .rotateDue: return "Rotate due"
        case .mcp: return "AI-allowed"
        }
    }
}

enum VaultListSort: String, CaseIterable, Identifiable {
    case name
    case createdNewest
    case createdOldest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return "Name"
        case .createdNewest: return "Newest"
        case .createdOldest: return "Oldest"
        }
    }
}

enum VaultListGrouping: String, CaseIterable, Identifiable {
    case none
    case prefix
    case createdDate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .prefix: return "Prefix"
        case .createdDate: return "Created"
        }
    }
}

struct VaultSecretSection: Identifiable, Equatable {
    let id: String
    let title: String
    let secrets: [Secret]
}

func vaultFilteredSecrets(
    _ secrets: [Secret],
    filter: VaultListFilter,
    search: String
) -> [Secret] {
    let base = secrets.filter { s in
        switch filter {
        case .all: return true
        case .expiring:
            return s.isExpired || (s.expiresAt.map {
                Calendar.current.dateComponents([.day], from: Date(), to: $0).day ?? 99
            } ?? 99) < 14
        case .rotateDue: return s.isRotationDue
        case .mcp: return s.mcpAllowed
        }
    }
    guard !search.isEmpty else { return base }
    return base.filter { $0.name.localizedCaseInsensitiveContains(search) }
}

func vaultSortedSecrets(_ secrets: [Secret], sort: VaultListSort) -> [Secret] {
    secrets.sorted { lhs, rhs in
        switch sort {
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        case .createdNewest:
            if lhs.createdAt == rhs.createdAt {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.createdAt > rhs.createdAt
        case .createdOldest:
            if lhs.createdAt == rhs.createdAt {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.createdAt < rhs.createdAt
        }
    }
}

func vaultSecretSections(
    _ secrets: [Secret],
    grouping: VaultListGrouping,
    sort: VaultListSort,
    calendar: Calendar = .current
) -> [VaultSecretSection] {
    let sorted = vaultSortedSecrets(secrets, sort: sort)
    switch grouping {
    case .none:
        return [VaultSecretSection(id: "all", title: "All secrets", secrets: sorted)]
    case .prefix:
        let grouped = Dictionary(grouping: sorted, by: vaultPrefixGroup)
        return grouped.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { key in
            VaultSecretSection(id: "prefix-\(key)", title: key, secrets: grouped[key] ?? [])
        }
    case .createdDate:
        let grouped = Dictionary(grouping: sorted) { secret in
            calendar.startOfDay(for: secret.createdAt)
        }
        let dates = grouped.keys.sorted(by: sort == .createdOldest ? (<) : (>))
        return dates.map { date in
            VaultSecretSection(
                id: "created-\(Int(date.timeIntervalSince1970))",
                title: vaultCreatedDateGroupTitle(date, calendar: calendar),
                secrets: grouped[date] ?? []
            )
        }
    }
}

private func vaultPrefixGroup(_ secret: Secret) -> String {
    let separators = CharacterSet(charactersIn: "_-.")
    let parts = secret.name.components(separatedBy: separators).filter { !$0.isEmpty }
    guard let first = parts.first, first.count < secret.name.count else { return "No prefix" }
    return first.uppercased()
}

private func vaultCreatedDateGroupTitle(_ date: Date, calendar: Calendar) -> String {
    if calendar.isDateInToday(date) { return "Today" }
    if calendar.isDateInYesterday(date) { return "Yesterday" }
    return date.formatted(date: .abbreviated, time: .omitted)
}

struct VaultSecretsCountLine: View {
    let secrets: [Secret]

    var body: some View {
        let rotate = secrets.filter(\.isRotationDue).count
        let expired = secrets.filter(\.isExpired).count
        HStack(spacing: Tokens.Space.xs) {
            Text("\(secrets.count)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Tokens.Text.primary)
            Text("secret\(secrets.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(Tokens.Text.secondary)
            if expired > 0 {
                Text("·").foregroundStyle(Tokens.Text.tertiary).font(.subheadline)
                Text("\(expired) expired").font(.subheadline).foregroundStyle(Tokens.Status.danger)
            }
            if rotate > 0 {
                Text("·").foregroundStyle(Tokens.Text.tertiary).font(.subheadline)
                Text("\(rotate) due to rotate").font(.subheadline).foregroundStyle(Tokens.Status.warning)
            }
            Spacer()
        }
    }
}
