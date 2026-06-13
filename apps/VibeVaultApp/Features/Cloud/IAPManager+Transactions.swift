import Foundation
import StoreKit

extension IAPManager {
    // MARK: - Transaction Handling

    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Deliver content to user
                    await self.handleTransaction(transaction)

                    // Finish transaction
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }

    func handleTransaction(_ transaction: StoreKit.Transaction) async {
        // Update purchased products
        await updatePurchasedProducts()

        // Send receipt to server
        await verifyReceiptWithServer(transaction: transaction)
    }

    func deliverPurchase(product: Product, transaction: StoreKit.Transaction) async {
        purchasedProductIDs.insert(product.id)

        // Send receipt to server
        await verifyReceiptWithServer(transaction: transaction)
    }

    func verifyReceiptWithServer(transaction: StoreKit.Transaction) async {
        guard cloudAuth.isAuthenticated else { return }

        do {
            // Get the appStoreReceipt
            guard let receiptURL = Bundle.main.appStoreReceiptURL,
                  let receipt = try? Data(contentsOf: receiptURL).base64EncodedString() else {
                return
            }

            let body: [String: Any] = [
                "receiptData": receipt,
                "productId": transaction.productID
            ]

            let data = try JSONSerialization.data(withJSONObject: body)

            guard let url = URL(string: "https://vibevault-api.your-account.workers.dev/api/subscription/verify-receipt") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(cloudAuth.authToken ?? "")", forHTTPHeaderField: "Authorization")
            request.httpBody = data

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                // Refresh subscription status
                await cloudAuth.verifySession()
            }

        } catch {
            print("Receipt verification failed: \(error)")
        }
    }

    // MARK: - Helpers

    nonisolated func checkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.invalidVerification
        case .verified(let safe):
            return safe
        }
    }
}
