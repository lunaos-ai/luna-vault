import Foundation
import SwiftUI
import StoreKit

/// In-App Purchase Manager for Vibe Vault Pro subscription
@MainActor
final class IAPManager: ObservableObject {
    static let shared = IAPManager()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var lastError: String?

    // Product IDs - must match App Store Connect
    let monthlyProductID = "dev.vibevault.subscription.monthly"
    let yearlyProductID = "dev.vibevault.subscription.yearly"

    let cloudAuth = CloudAuthService.shared
    private var updateListenerTask: Task<Void, Error>?

    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        Task {
            await requestProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    var hasActiveSubscription: Bool {
        !purchasedProductIDs.isEmpty
    }
}

enum StoreError: Error {
    case invalidVerification
}
