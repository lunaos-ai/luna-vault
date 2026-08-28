import Foundation

public enum PlatformSupport {
    public enum Host: String, Sendable {
        case macOS
        case linux
        case windows
        case unknown
    }

    public static var host: Host {
        #if os(macOS)
        return .macOS
        #elseif os(Linux)
        return .linux
        #elseif os(Windows)
        return .windows
        #else
        return .unknown
        #endif
    }

    /// Native GUI: SwiftUI on macOS (`VibeVaultApp`); SwiftCrossUI desktop on all platforms.
    public static var hasNativeApp: Bool {
        true
    }

    /// Keychain / LocalAuthentication available.
    public static var hasAppleKeychain: Bool {
        #if canImport(Security) && canImport(LocalAuthentication)
        return true
        #else
        return false
        #endif
    }

    public static var dataDirectoryHint: String {
        switch host {
        case .macOS:
            return "~/Library/Application Support/vibe-vault"
        case .linux:
            return "${XDG_DATA_HOME:-~/.local/share}/vibe-vault"
        case .windows:
            return "%APPDATA%\\\\vibe-vault"
        case .unknown:
            return "(platform data directory)/vibe-vault"
        }
    }
}
