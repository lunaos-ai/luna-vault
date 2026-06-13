import Foundation
import SwiftUI
import VaultCore

/// Session lifecycle for `CloudAuthService`:
/// verification, token refresh, logout, and restoring a saved session.
extension CloudAuthService {

    // MARK: - Session

    func loadSavedSession() {
        if authToken != nil, let userId = token(forKey: userIdKey) {
            self.userId = userId
            Task {
                await verifySession()
            }
        }
    }

    func verifySession() async {
        guard let token = authToken else {
            isAuthenticated = false
            return
        }

        do {
            guard let url = URL(string: "\(apiBaseURL)/api/auth/verify") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  json["valid"] as? Bool == true else {
                // Token invalid, clear session
                logout()
                return
            }

            self.userEmail = json["email"] as? String
            self.subscriptionStatus = json["subscriptionStatus"] as? String ?? "free"
            self.backupEnabled = json["backupEnabled"] as? Bool ?? false
            self.isAuthenticated = true

        } catch {
            // Network error — keep the session (might be a transient outage).
        }
    }

    func logout() {
        clearTokens()
        userId = nil
        userEmail = nil
        isAuthenticated = false
        subscriptionStatus = "free"
        backupEnabled = false
    }

    func refreshToken() async -> Bool {
        guard let refreshToken = token(forKey: refreshTokenKey) else {
            return false
        }

        do {
            let body: [String: Any] = ["refreshToken": refreshToken]
            let data = try JSONSerialization.data(withJSONObject: body)

            guard let url = URL(string: "\(apiBaseURL)/api/auth/refresh") else { return false }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data

            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let newToken = json["token"] as? String,
                  let newRefreshToken = json["refreshToken"] as? String,
                  let userId = self.userId else {
                return false
            }

            saveTokens(token: newToken, refreshToken: newRefreshToken, userId: userId)
            return true

        } catch {
            return false
        }
    }
}
