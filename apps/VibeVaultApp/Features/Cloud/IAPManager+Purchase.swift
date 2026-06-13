import Foundation
import StoreKit

extension IAPManager {
    // MARK: - Purchase

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // Deliver content to user
                await deliverPurchase(product: product, transaction: transaction)

                // Finish transaction
                await transaction.finish()

                return true

            case .userCancelled:
                return false

            case .pending:
                lastError = "Purchase pending - waiting for approval"
                return false

            @unknown default:
                lastError = "Unknown purchase result"
                return false
            }
        } catch StoreError.invalidVerification {
            lastError = "Purchase verification failed"
            return false
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            return true
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
            return false
        }
    }
}
