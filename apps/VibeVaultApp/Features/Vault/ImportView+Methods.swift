import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VaultCore

extension ImportView {
    func pickDotenv() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = []
        panel.treatsFilePackagesAsDirectories = true
        panel.showsHiddenFiles = true
        panel.begin { resp in
            if resp == .OK, let url = panel.url {
                openDotenvReview(url)
            }
        }
    }

    func pickPasswordExport(profile: PasswordManagerImportProfile) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = []
        panel.treatsFilePackagesAsDirectories = true
        panel.begin { resp in
            if resp == .OK, let url = panel.url {
                openPasswordExportReview(url, profile: profile)
            }
        }
    }

    func pickCredentialImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.treatsFilePackagesAsDirectories = true
        panel.begin { resp in
            if resp == .OK, let url = panel.url {
                openCredentialImageReview(url)
            }
        }
    }

    func openDotenvReview(_ url: URL) {
        do {
            let items = try DotenvImporter.parseFile(at: url)
            guard !items.isEmpty else {
                env.importStatus = "No secrets found in \(url.lastPathComponent)"
                return
            }
            reviewSheet = ImportReviewPayload(
                subtitle: url.path,
                rows: ImportRowState.from(items, sourceFile: url.lastPathComponent),
                notes: "imported from \(url.lastPathComponent)"
            )
        } catch {
            env.importStatus = "error: \(error)"
        }
    }

    func openPasswordExportReview(_ url: URL, profile: PasswordManagerImportProfile) {
        do {
            let items = try PasswordManagerCSVImporter.parseFile(at: url, profile: profile)
            guard !items.isEmpty else {
                env.importStatus = "No passwords found in \(url.lastPathComponent)"
                return
            }
            reviewSheet = ImportReviewPayload(
                subtitle: "\(profile.label) · \(url.lastPathComponent)",
                rows: ImportRowState.from(items, sourceFile: url.lastPathComponent),
                notes: "imported from \(profile.label) export"
            )
        } catch {
            env.importStatus = "error: \(error)"
        }
    }

    func openCredentialImageReview(_ url: URL) {
        imageOCRRunning = true
        imageOCRStatus = "Reading \(url.lastPathComponent)…"
        Task {
            do {
                let items = try await Task.detached {
                    try ImageCredentialImporter.recognizeFile(at: url)
                }.value
                imageOCRRunning = false
                guard !items.isEmpty else {
                    imageOCRStatus = "No credential fields found in \(url.lastPathComponent)"
                    return
                }
                imageOCRStatus = "Found \(items.count) candidate\(items.count == 1 ? "" : "s")"
                reviewSheet = ImportReviewPayload(
                    subtitle: "Image OCR · \(url.lastPathComponent)",
                    rows: ImportRowState.from(items, sourceFile: url.lastPathComponent),
                    notes: "imported from image OCR: \(url.lastPathComponent)"
                )
            } catch {
                imageOCRRunning = false
                imageOCRStatus = "error: \(error)"
                env.importStatus = "error: \(error)"
            }
        }
    }

    func openOnePasswordReview() {
        do {
            let items = try OnePasswordImporter.fetch(itemRef: opItemRef)
            guard !items.isEmpty else {
                env.importStatus = "No fields found in 1Password item"
                return
            }
            reviewSheet = ImportReviewPayload(
                subtitle: "1Password CLI · \(opItemRef)",
                rows: ImportRowState.from(items),
                notes: "imported from 1Password: \(opItemRef)"
            )
        } catch {
            env.importStatus = "error: \(error)"
        }
    }

    func probeOpCLI() async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["op", "--version"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return "op CLI not found. brew install --cask 1password-cli" }
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            let v = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "op CLI \(v) detected. If import fails, sign in: `op signin`."
        }
        return "op CLI present but not signed in. Run `op signin` in your terminal."
    }
}
