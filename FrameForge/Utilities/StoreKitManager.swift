import StoreKit
import SwiftUI

@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    static let proID = "com.frameforge.pro"
    static let tipSmallID = "com.frameforge.tip.small"
    static let tipMediumID = "com.frameforge.tip.medium"
    static let tipLargeID = "com.frameforge.tip.large"

    private static let allProductIDs: Set<String> = [
        proID, tipSmallID, tipMediumID, tipLargeID
    ]

    @Published var isPro = false
    @Published var hasTipped = false
    @Published var products: [Product] = []
    @Published var purchaseInProgress = false

    private var transactionListener: Task<Void, Never>?

    private init() {
        isPro = UserDefaults.standard.bool(forKey: "isPro")
        hasTipped = UserDefaults.standard.bool(forKey: "hasTipped")
    }

    func start() {
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
    }

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: Self.allProductIDs)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> Bool {
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await handleTransaction(transaction)
            await transaction.finish()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                await handleTransaction(transaction)
            }
        }
    }

    var proProduct: Product? {
        products.first { $0.id == Self.proID }
    }

    var tipProducts: [Product] {
        products.filter { $0.id.contains("tip") }.sorted { $0.price < $1.price }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? await self.checkVerified(result) {
                    await self.handleTransaction(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    private func handleTransaction(_ transaction: Transaction) async {
        if transaction.productID == Self.proID {
            isPro = true
            UserDefaults.standard.set(true, forKey: "isPro")
        } else if transaction.productID.contains("tip") {
            hasTipped = true
            UserDefaults.standard.set(true, forKey: "hasTipped")
        }
    }
}
