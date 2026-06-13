import Foundation
import StoreKit

extension IAPManager {
    // MARK: - Product Loading

    func requestProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: [monthlyProductID, yearlyProductID])
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            lastError = "Failed to load products: \(error.localizedDescription)"
        }
    }

    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []

        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchasedIDs.insert(transaction.productID)
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }

        purchasedProductIDs = purchasedIDs
    }

    func price(for productID: String) -> String {
        guard let product = products.first(where: { $0.id == productID }) else {
            return "--"
        }
        return product.displayPrice
    }
}
