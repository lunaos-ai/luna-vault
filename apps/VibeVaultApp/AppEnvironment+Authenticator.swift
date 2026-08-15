import AppKit
import Foundation
import VaultCore

extension AppEnvironment {
    func refreshAuthenticators() {
        do { authenticatorAccounts = try authenticatorService.list() }
        catch { lastError = "\(error)" }
    }

    func addAuthenticator(input: String, issuer: String?, accountName: String?) async -> Bool {
        do {
            _ = try await authenticatorService.add(
                input: input, issuer: issuer, accountName: accountName
            )
            refreshAuthenticators()
            showToast("Authenticator saved", feedback: .success)
            return true
        } catch {
            lastError = "\(error)"
            showToast("Could not save authenticator", feedback: .caution)
            return false
        }
    }

    func deleteAuthenticator(id: UUID) async {
        do {
            try await authenticatorService.delete(id: id)
            refreshAuthenticators()
            showToast("Authenticator deleted", feedback: .tick)
        } catch {
            lastError = "\(error)"
            showToast("Could not delete authenticator", feedback: .caution)
        }
    }

    func convertAttachedAuthenticator(secretName: String) async {
        do {
            _ = try await authenticatorService.convertAttachedTOTP(
                secretName: secretName, vaultService: service
            )
            refresh()
            showToast("Converted to standalone authenticator", feedback: .success)
        } catch {
            lastError = "\(error)"
            showToast("Could not convert authenticator", feedback: .caution)
        }
    }

    func toggleAuthenticatorFavorite(_ account: AuthenticatorAccountMetadata) async {
        do {
            try await authenticatorService.updateMetadata(
                id: account.id, issuer: account.issuer, accountName: account.accountName,
                favorite: !account.favorite
            )
            refreshAuthenticators()
        } catch { lastError = "\(error)" }
    }

    func copyAuthenticatorValue(_ value: String, expiresAfter seconds: Int = 30) {
        let board = NSPasteboard.general
        board.clearContents()
        guard board.setString(value, forType: .string) else { return }
        let changeCount = board.changeCount
        showToast("Copied for \(seconds) seconds")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            if NSPasteboard.general.changeCount == changeCount {
                NSPasteboard.general.clearContents()
            }
        }
    }
}
