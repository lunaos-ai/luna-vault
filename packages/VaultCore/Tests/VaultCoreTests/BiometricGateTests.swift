import XCTest
@testable import VaultCore

final class BiometricGateTests: XCTestCase {
    func test_default_session_is_300_seconds() {
        let gate = BiometricGate()
        XCTAssertEqual(gate.sessionWindowSeconds(), 300)
    }

    func test_init_with_custom_window() {
        let gate = BiometricGate(sessionWindow: 60)
        XCTAssertEqual(gate.sessionWindowSeconds(), 60)
    }

    func test_setSessionWindow_updates_value() {
        let gate = BiometricGate(sessionWindow: 60)
        gate.setSessionWindow(900)
        XCTAssertEqual(gate.sessionWindowSeconds(), 900)
    }

    func test_setSessionWindow_clamps_negative_to_zero() {
        let gate = BiometricGate()
        gate.setSessionWindow(-10)
        XCTAssertEqual(gate.sessionWindowSeconds(), 0)
    }

    func test_resetSession_does_not_throw() {
        let gate = BiometricGate()
        gate.resetSession()
    }

    func test_noop_gate_implements_protocol() async throws {
        let gate = NoopBiometricGate()
        gate.setSessionWindow(120)
        XCTAssertEqual(gate.sessionWindowSeconds(), 120)
        try await gate.authenticate(reason: "test")
        gate.resetSession()
    }
}
