import Foundation
import SwiftUI
import AppKit
import VaultCore

/// OAuth sign-in flows for `CloudAuthService` (Google, GitHub) plus completion polling.
extension CloudAuthService {

    // MARK: - OAuth Methods

    func signInWithGoogle() async -> Bool {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            // Initiate Google OAuth flow via backend
            guard let url = URL(string: "\(apiBaseURL)/api/auth/google") else {
                lastError = "Invalid URL"
                return false
            }

            let deviceId = Self.getDeviceIdentifier()
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["deviceId": deviceId])

            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let authUrl = json["authUrl"] as? String else {
                lastError = "Failed to initiate Google sign-in"
                return false
            }

            // Open browser for OAuth (in real implementation, use ASWebAuthenticationSession)
            if let oauthURL = URL(string: authUrl) {
                NSWorkspace.shared.open(oauthURL)
            }

            // Poll for OAuth completion or use callback handler
            return await pollForOAuthCompletion(provider: "google")

        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func signInWithGitHub() async -> Bool {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            // Initiate GitHub OAuth flow via backend
            guard let url = URL(string: "\(apiBaseURL)/api/auth/github") else {
                lastError = "Invalid URL"
                return false
            }

            let deviceId = Self.getDeviceIdentifier()
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["deviceId": deviceId])

            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let authUrl = json["authUrl"] as? String else {
                lastError = "Failed to initiate GitHub sign-in"
                return false
            }

            // Open browser for OAuth
            if let oauthURL = URL(string: authUrl) {
                NSWorkspace.shared.open(oauthURL)
            }

            return await pollForOAuthCompletion(provider: "github")

        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func pollForOAuthCompletion(provider: String) async -> Bool {
        // Poll backend for OAuth completion status
        // In production, use WebSocket or callback URL scheme
        let maxAttempts = 60 // 2 minutes (2 second intervals)

        for _ in 0..<maxAttempts {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            do {
                guard let pollUrl = URL(string: "\(apiBaseURL)/api/auth/oauth/status?deviceId=\(Self.getDeviceIdentifier())") else { continue }

                let (data, _) = try await URLSession.shared.data(from: pollUrl)

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String {

                    if status == "completed",
                       let token = json["token"] as? String,
                       let refreshToken = json["refreshToken"] as? String,
                       let userId = json["userId"] as? String {

                        saveTokens(token: token, refreshToken: refreshToken, userId: userId)
                        self.userId = userId
                        self.userEmail = json["email"] as? String
                        self.isAuthenticated = true
                        self.subscriptionStatus = json["subscriptionStatus"] as? String ?? "free"
                        return true
                    } else if status == "failed" {
                        lastError = json["error"] as? String ?? "OAuth failed"
                        return false
                    }
                }
            } catch {
                continue
            }
        }

        lastError = "Sign-in timed out. Please try again."
        return false
    }
}
