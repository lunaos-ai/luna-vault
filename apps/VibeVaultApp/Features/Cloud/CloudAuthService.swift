import Foundation
import SwiftUI
import VaultCore

/// Cloud authentication service for Vibe Vault
/// Handles user registration, login, and token management for cloud features
@MainActor
final class CloudAuthService: ObservableObject {
    static let shared = CloudAuthService()

    @Published var isAuthenticated = false
    @Published var userEmail: String?
    @Published var userId: String?
    @Published var subscriptionStatus: String = "free"
    @Published var backupEnabled = false
    @Published var isLoading = false
    @Published var lastError: String?

    let apiBaseURL = "https://vibevault-api.your-account.workers.dev" // Update this
    let tokenKey = "vibevault_cloud_token"
    let refreshTokenKey = "vibevault_refresh_token"
    let userIdKey = "vibevault_user_id"

    /// Auth tokens live in the Keychain, never in UserDefaults (which is a plain
    /// plist on disk). Separate service so cloud tokens don't mix with secrets.
    let tokenStore: PreferenceStoring = KeychainPrefs(service: "dev.vibevault.cloud")

    private init() {
        migrateLegacyTokens()
        loadSavedSession()
    }

    // MARK: - Token Management

    func token(forKey key: String) -> String? {
        tokenStore.data(forKey: key).flatMap { String(data: $0, encoding: .utf8) }
    }

    private func setToken(_ value: String?, forKey key: String) {
        tokenStore.set(value.flatMap { Data($0.utf8) }, forKey: key)
    }

    var authToken: String? { token(forKey: tokenKey) }

    func saveTokens(token: String, refreshToken: String, userId: String) {
        setToken(token, forKey: tokenKey)
        setToken(refreshToken, forKey: refreshTokenKey)
        setToken(userId, forKey: userIdKey)
    }

    func clearTokens() {
        for key in [tokenKey, refreshTokenKey, userIdKey] { setToken(nil, forKey: key) }
    }

    /// Move any tokens written by an earlier build (UserDefaults) into the
    /// Keychain once, then scrub them from the plist.
    private func migrateLegacyTokens() {
        for key in [tokenKey, refreshTokenKey, userIdKey] {
            guard let legacy = UserDefaults.standard.string(forKey: key) else { continue }
            if token(forKey: key) == nil { setToken(legacy, forKey: key) }
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Device Identifier Helper

    /// Returns a stable per-device identifier, generating and persisting one if needed.
    /// Internal so OAuth/Session extensions can reach it.
    static func getDeviceIdentifier() -> String {
        // Use system UUID from keychain if available, otherwise generate and store
        let key = "vibevault_device_id"

        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }

        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    // MARK: - API Methods

    func register(email: String, password: String) async -> Bool {
        isLoading = true
        lastError = nil

        defer { isLoading = false }

        do {
            let deviceId = Self.getDeviceIdentifier()

            let body: [String: Any] = [
                "email": email,
                "password": password,
                "deviceId": deviceId
            ]

            let data = try JSONSerialization.data(withJSONObject: body)

            guard let url = URL(string: "\(apiBaseURL)/api/auth/register") else {
                lastError = "Invalid URL"
                return false
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data

            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                   let error = errorJson["error"] as? String {
                    lastError = error
                } else {
                    lastError = "Registration failed"
                }
                return false
            }

            guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let token = json["token"] as? String,
                  let refreshToken = json["refreshToken"] as? String,
                  let userId = json["userId"] as? String else {
                lastError = "Invalid response"
                return false
            }

            saveTokens(token: token, refreshToken: refreshToken, userId: userId)
            self.userId = userId
            self.userEmail = email
            self.isAuthenticated = true
            self.subscriptionStatus = json["subscriptionStatus"] as? String ?? "free"
            self.backupEnabled = json["backupEnabled"] as? Bool ?? false

            return true

        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func login(email: String, password: String) async -> Bool {
        isLoading = true
        lastError = nil

        defer { isLoading = false }

        do {
            let deviceId = Self.getDeviceIdentifier()

            let body: [String: Any] = [
                "email": email,
                "password": password,
                "deviceId": deviceId
            ]

            let data = try JSONSerialization.data(withJSONObject: body)

            guard let url = URL(string: "\(apiBaseURL)/api/auth/login") else {
                lastError = "Invalid URL"
                return false
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data

            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                   let error = errorJson["error"] as? String {
                    lastError = error
                } else {
                    lastError = "Login failed"
                }
                return false
            }

            guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let token = json["token"] as? String,
                  let refreshToken = json["refreshToken"] as? String,
                  let userId = json["userId"] as? String else {
                lastError = "Invalid response"
                return false
            }

            saveTokens(token: token, refreshToken: refreshToken, userId: userId)
            self.userId = userId
            self.userEmail = json["email"] as? String
            self.isAuthenticated = true
            self.subscriptionStatus = json["subscriptionStatus"] as? String ?? "free"
            self.backupEnabled = json["backupEnabled"] as? Bool ?? false

            return true

        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
