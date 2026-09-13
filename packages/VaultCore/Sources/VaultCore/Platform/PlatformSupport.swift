import Foundation

public enum PlatformSupport {
    public enum Host: String, Sendable {
        case macOS
        case linux
        case windows
        case unknown
    }

    /// Where the vault master key is stored for this build.
    public enum MasterKeyBackend: String, Sendable {
        case appleKeychain
        /// Mode-0600 file fallback when no OS keyring is present.
        case fileSecureStore
        /// Windows DPAPI blob bound to the current user.
        case windowsDPAPI
        /// Linux Secret Service (libsecret) with file fallback.
        case linuxSecretService
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

    /// Native GUI: SwiftUI on macOS (`VibeVaultApp`); SwiftCrossUI desktop elsewhere.
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

    public static var masterKeyBackend: MasterKeyBackend {
        if hasAppleKeychain { return .appleKeychain }
        #if os(Windows)
        return .windowsDPAPI
        #elseif os(Linux)
        return .linuxSecretService
        #else
        return .fileSecureStore
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
