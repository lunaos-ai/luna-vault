import Foundation

// MARK: - Backup Models

extension CloudBackupService {
    struct CloudBackup: Identifiable, Codable {
        let id: String
        let size: Int
        let checksum: String?
        let deviceName: String
        let createdAt: Date
    }

    struct BackupSchedule: Codable {
        let enabled: Bool
        let frequency: String // daily, weekly, monthly
        let dayOfWeek: Int? // 0-6 for weekly
        let hourOfDay: Int // 0-23
        let lastBackupAt: Date?
        let nextBackupAt: Date?
    }
}

// MARK: - Date Extensions

extension Date {
    var iso8601String: String {
        return ISO8601DateFormatter().string(from: self)
    }
}
