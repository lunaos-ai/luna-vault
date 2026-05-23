import Foundation
import LocalAuthentication

public protocol BiometricGating: Sendable {
    func authenticate(reason: String) async throws
    func resetSession()
    func setSessionWindow(_ seconds: TimeInterval)
    func sessionWindowSeconds() -> TimeInterval
}

public final class BiometricGate: BiometricGating, @unchecked Sendable {
    private var sessionWindow: TimeInterval
    private var lastSuccess: Date?
    private let queue = DispatchQueue(label: "dev.vibevault.biometric")

    public init(sessionWindow: TimeInterval = 300) {
        self.sessionWindow = sessionWindow
    }

    public func setSessionWindow(_ seconds: TimeInterval) {
        queue.sync { sessionWindow = max(0, seconds) }
    }

    public func sessionWindowSeconds() -> TimeInterval {
        queue.sync { sessionWindow }
    }

    public func authenticate(reason: String) async throws {
        if isSessionValid() { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw SecretError.biometricDenied
        }
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            queue.sync { lastSuccess = Date() }
        } catch {
            throw SecretError.biometricDenied
        }
    }

    public func resetSession() {
        queue.sync { lastSuccess = nil }
    }

    private func isSessionValid() -> Bool {
        queue.sync {
            guard let last = lastSuccess else { return false }
            return Date().timeIntervalSince(last) < sessionWindow
        }
    }
}

public final class NoopBiometricGate: BiometricGating, @unchecked Sendable {
    private var window: TimeInterval = 300
    public init() {}
    public func authenticate(reason: String) async throws {}
    public func resetSession() {}
    public func setSessionWindow(_ seconds: TimeInterval) { window = seconds }
    public func sessionWindowSeconds() -> TimeInterval { window }
}
