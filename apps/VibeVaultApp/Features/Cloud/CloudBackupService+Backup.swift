import Foundation
import VaultCore

// MARK: - Backup Operations

extension CloudBackupService {
    func createBackup(secrets: [Secret]) async -> Bool {
        guard authService.isAuthenticated, authService.backupEnabled else {
            lastError = "Cloud backup not enabled"
            return false
        }

        isLoading = true
        lastError = nil

        defer { isLoading = false }

        do {
            // Serialize secrets to JSON
            let backupData = try serializeSecrets(secrets)

            // Encrypt the backup data
            guard let encryptedData = encryptBackup(backupData) else {
                lastError = "Encryption failed"
                return false
            }

            // Calculate checksum
            let checksum = calculateChecksum(backupData)

            // Get device name
            let deviceName = Host.current().localizedName ?? "Mac"

            let body: [String: Any] = [
                "backupData": encryptedData,
                "checksum": checksum,
                "deviceName": deviceName
            ]

            let data = try JSONSerialization.data(withJSONObject: body)

            guard let url = URL(string: "\(apiBaseURL)/api/backup/create") else {
                lastError = "Invalid URL"
                return false
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(authService.authToken ?? "")", forHTTPHeaderField: "Authorization")
            request.httpBody = data

            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  json["success"] as? Bool == true else {
                if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                   let error = errorJson["error"] as? String {
                    lastError = error
                } else {
                    lastError = "Backup creation failed"
                }
                return false
            }

            lastBackupDate = Date()
            await listBackups()
            return true

        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func listBackups() async {
        guard authService.isAuthenticated else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            guard let url = URL(string: "\(apiBaseURL)/api/backup/list") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(authService.authToken ?? "")", forHTTPHeaderField: "Authorization")

            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let backupsData = json["backups"] as? [[String: Any]] else {
                return
            }

            backups = backupsData.compactMap { backupDict -> CloudBackup? in
                guard let id = backupDict["id"] as? String,
                      let size = backupDict["backup_size"] as? Int,
                      let deviceName = backupDict["device_name"] as? String,
                      let createdAtString = backupDict["created_at"] as? String else {
                    return nil
                }

                let formatter = ISO8601DateFormatter()
                let createdAt = formatter.date(from: createdAtString) ?? Date()

                return CloudBackup(
                    id: id,
                    size: size,
                    checksum: backupDict["checksum"] as? String,
                    deviceName: deviceName,
                    createdAt: createdAt
                )
            }

        } catch {
            print("Failed to list backups: \(error)")
        }
    }

    func restoreBackup(backupId: String) async -> [Secret]? {
        guard authService.isAuthenticated else {
            lastError = "Not authenticated"
            return nil
        }

        isLoading = true
        lastError = nil

        defer { isLoading = false }

        do {
            guard let url = URL(string: "\(apiBaseURL)/api/backup/\(backupId)/restore") else {
                lastError = "Invalid URL"
                return nil
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(authService.authToken ?? "")", forHTTPHeaderField: "Authorization")

            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  json["success"] as? Bool == true,
                  let backupData = json["data"] as? String else {
                if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                   let error = errorJson["error"] as? String {
                    lastError = error
                } else {
                    lastError = "Restore failed"
                }
                return nil
            }

            // Decrypt and deserialize
            guard let decryptedData = decryptBackup(backupData),
                  let secrets = try? deserializeSecrets(decryptedData) else {
                lastError = "Decryption failed"
                return nil
            }

            return secrets

        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func deleteBackup(backupId: String) async -> Bool {
        guard authService.isAuthenticated else { return false }

        isLoading = true
        defer { isLoading = false }

        do {
            guard let url = URL(string: "\(apiBaseURL)/api/backup/\(backupId)") else { return false }

            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(authService.authToken ?? "")", forHTTPHeaderField: "Authorization")

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return false
            }

            await listBackups()
            return true

        } catch {
            return false
        }
    }
}
