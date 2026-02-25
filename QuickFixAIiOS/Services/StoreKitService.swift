import StoreKit
import FirebaseAuth

@MainActor
@Observable
final class StoreKitService {

    // MARK: - State

    var products: [Product] = []
    var purchaseInProgress = false
    var purchaseError: String? = nil

    // Runs for the app's lifetime — picks up renewals, family-sharing grants,
    // and transactions that complete while the app was backgrounded.
    nonisolated(unsafe) private var updateListenerTask: Task<Void, Never>?

    // MARK: - Init / Deinit

    init() {
        updateListenerTask = listenForTransactionUpdates()
        Task { await loadProducts() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: AppConfig.StoreKitProducts.all)
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            // Products aren't available until configured in App Store Connect.
            // This is expected in development — no user-facing action needed.
        }
    }

    // MARK: - Purchase

    /// Initiates a StoreKit purchase for the given product ID.
    /// Throws if StoreKit reports an error. On success, verifies the
    /// transaction with the backend and finishes it.
    func purchase(productId: String) async throws {
        guard let product = products.first(where: { $0.id == productId }) else { return }

        purchaseInProgress = true
        defer { purchaseInProgress = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // jwsRepresentation is on VerificationResult<Transaction>, not Transaction.
            let jws = verification.jwsRepresentation
            if case .verified(let transaction) = verification {
                await verifyWithBackend(jws: jws)
                await transaction.finish()
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Restore Purchases

    /// Re-syncs verified transactions from the App Store.
    /// Any outstanding verified transactions flow through the update listener
    /// and get verified with the backend automatically.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Transaction Update Listener

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                let jws = result.jwsRepresentation
                guard case .verified(let transaction) = result else { continue }
                await self?.verifyWithBackend(jws: jws)
                await transaction.finish()
            }
        }
    }

    // MARK: - Backend Verification

    /// Sends the signed JWS transaction to the backend for server-side verification
    /// and Firestore update. The UserViewModel's real-time listener picks up
    /// the Firestore change automatically — no manual state update needed here.
    private func verifyWithBackend(jws: String) async {
        do {
            try await APIService.shared.post(
                "/api/apple/verify-purchase",
                body: ["signedTransactionInfo": jws],
                requiresAuth: true
            )
        } catch {
            // Non-fatal: Apple's server notifications will also update Firestore
            // if the immediate backend call fails.
        }
    }
}
