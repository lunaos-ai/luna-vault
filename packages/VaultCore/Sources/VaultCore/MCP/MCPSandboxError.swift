import Foundation

public enum MCPSandboxError: Error, Equatable, CustomStringConvertible, LocalizedError, Sendable {
    case passkeyTooShort
    case passkeyMismatch
    case passkeyNotEnrolled
    case unauthorized
    case listenFailed(String)
    case mcpBinaryMissing
    case keyDerivationFailed

    public var description: String {
        switch self {
        case .passkeyTooShort:
            return "sandbox passkey must be at least \(MCPSandboxSettings.minPasskeyLength) characters"
        case .passkeyMismatch:
            return "sandbox passkeys did not match"
        case .passkeyNotEnrolled:
            return "no sandbox passkey enrolled; run vibevault mcp passkey set"
        case .unauthorized:
            return "sandbox MCP unauthorized"
        case .listenFailed(let message):
            return "sandbox MCP listen failed: \(message)"
        case .mcpBinaryMissing:
            return "vibevault-mcp not found"
        case .keyDerivationFailed:
            return "sandbox passkey derivation failed"
        }
    }

    public var errorDescription: String? { description }
}
