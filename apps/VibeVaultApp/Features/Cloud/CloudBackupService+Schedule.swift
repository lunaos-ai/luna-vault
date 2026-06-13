import Foundation

// MARK: - Scheduling

extension CloudBackupService {
    func getSchedule() async {
        guard authService.isAuthenticated else { return }

        do {
            guard let url = URL(string: "\(apiBaseURL)/api/backup/schedule") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(authService.authToken ?? "")", forHTTPHeaderField: "Authorization")

            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                return
            }

            isBackupScheduled = json["enabled"] as? Bool ?? false

            if let nextBackupString = json["nextBackupAt"] as? String {
                let formatter = ISO8601DateFormatter()
                nextScheduledBackup = formatter.date(from: nextBackupString)
            }

        } catch {
            print("Failed to get schedule: \(error)")
        }
    }

    func setSchedule(frequency: String, dayOfWeek: Int?, hourOfDay: Int) async -> Bool {
        guard authService.isAuthenticated else { return false }

        do {
            var body: [String: Any] = [
                "frequency": frequency,
                "hourOfDay": hourOfDay
            ]

            if let dayOfWeek = dayOfWeek {
                body["dayOfWeek"] = dayOfWeek
            }

            let data = try JSONSerialization.data(withJSONObject: body)

            guard let url = URL(string: "\(apiBaseURL)/api/backup/schedule") else { return false }

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
                return false
            }

            isBackupScheduled = true

            if let nextBackupString = json["nextBackupAt"] as? String {
                let formatter = ISO8601DateFormatter()
                nextScheduledBackup = formatter.date(from: nextBackupString)
            }

            saveLocalSchedule(frequency: frequency, dayOfWeek: dayOfWeek, hourOfDay: hourOfDay)
            return true

        } catch {
            return false
        }
    }

    // MARK: - Local Schedule Storage

    func saveLocalSchedule(frequency: String, dayOfWeek: Int?, hourOfDay: Int) {
        UserDefaults.standard.set(frequency, forKey: "vibevault_backup_frequency")
        UserDefaults.standard.set(dayOfWeek, forKey: "vibevault_backup_dayOfWeek")
        UserDefaults.standard.set(hourOfDay, forKey: "vibevault_backup_hourOfDay")
    }

    func loadLocalSchedule() {
        // Load saved schedule if any
        let frequency = UserDefaults.standard.string(forKey: "vibevault_backup_frequency")
        isBackupScheduled = frequency != nil
    }
}
