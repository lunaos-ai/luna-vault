import Foundation

public enum PlatformDateFormat {
    private static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    public static func logTimestamp(_ date: Date) -> String {
        logFormatter.string(from: date)
    }

    public static func timeOnly(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
