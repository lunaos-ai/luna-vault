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

    private init() {
        loadSavedSession()
    }

    // MARK: - Token Management

    var authToken: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    func saveTokens(token: String, refreshToken: String, userId: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        UserDefaults.standard.set(userId, forKey: userIdKey)
    }

    func clearTokens() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
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
