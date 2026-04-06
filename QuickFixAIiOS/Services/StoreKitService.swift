import RevenueCat
import FirebaseAuth
import FirebaseFirestore

@MainActor
@Observable
final class RevenueCatService {

    // MARK: - State

    var purchaseInProgress = false
    var purchaseError: String? = nil

    // MARK: - Purchase

    func purchase(productId: String) async throws {
        let storeProducts: [StoreProduct] = await withCheckedContinuation { continuation in
            Purchases.shared.getProducts([productId]) { products in
                continuation.resume(returning: products)
            }
        }
        guard let product = storeProducts.first else { return }

        purchaseInProgress = true
        defer { purchaseInProgress = false }

        let (_, customerInfo, userCancelled): (RevenueCat.StoreTransaction?, CustomerInfo?, Bool) =
            try await withCheckedThrowingContinuation { continuation in
                Purchases.shared.purchase(product: product) { transaction, customerInfo, error, userCancelled in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: (transaction, customerInfo, userCancelled))
                    }
                }
            }

        guard !userCancelled else { return }
        await syncToFirestore(customerInfo: customerInfo, productId: productId)
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        do {
            let customerInfo: CustomerInfo? = try await withCheckedThrowingContinuation { continuation in
                Purchases.shared.restorePurchases { info, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: info)
                    }
                }
            }
            await syncToFirestore(customerInfo: customerInfo, productId: nil)
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Firestore Sync

    /// RC verifies the purchase with Apple internally. We use the resulting
    /// CustomerInfo to update Firestore directly so the UserViewModel listener
    /// picks up the change and dismisses the paywall immediately.
    private func syncToFirestore(customerInfo: CustomerInfo?, productId: String?) async {
        guard let uid = Auth.auth().currentUser?.uid,
              let info = customerInfo,
              !info.entitlements.active.isEmpty else { return }

        let activeProductId = productId ?? info.activeSubscriptions.first
        let plan = Self.plan(from: activeProductId)
        let planInfo = plan.flatMap { AppConfig.plan(for: $0) }
        let entitlement = info.entitlements.active.values.first
        let isTrial = entitlement?.periodType == .trial

        var data: [String: Any] = [
            "subscriptionStatus": isTrial ? "trialing" : "active",
            "paymentProvider": "apple",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let plan { data["plan"] = plan }
        if let credits = planInfo?.credits { data["credits"] = credits }
        if isTrial {
            data["wasOnTrial"] = true
            if let exp = entitlement?.expirationDate {
                data["trialEndDate"] = Timestamp(date: exp)
            }
        }

        do {
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .updateData(data)
        } catch {
            purchaseError = "Your subscription is active. Tap \"Restore Purchases\" if the app doesn't update automatically."
        }
    }

    private static func plan(from productId: String?) -> String? {
        guard let id = productId else { return nil }
        if id.contains("starter") { return "starter" }
        if id.contains("pro") { return "pro" }
        if id.contains("premium") { return "premium" }
        return nil
    }
}
