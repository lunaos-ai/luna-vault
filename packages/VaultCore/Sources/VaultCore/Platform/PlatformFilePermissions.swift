import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

enum PlatformFilePermissions {
    /// Restrict a file to the current user. Unix uses mode 0600; Windows relies on NTFS ACLs / DPAPI.
    static func restrictToOwner(_ url: URL) {
        #if os(Windows)
        return
        #else
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
        #endif
    }

    static func isOwnerPrivateRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true else {
            return false
        }
        #if os(Windows)
        return true
        #else
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let owner = attributes[.ownerAccountID] as? NSNumber,
              owner.uint32Value == geteuid(),
              let permissions = attributes[.posixPermissions] as? NSNumber,
              permissions.intValue & 0o077 == 0 else {
            return false
        }
        return true
        #endif
    }
}
