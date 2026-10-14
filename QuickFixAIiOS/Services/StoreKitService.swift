import RevenueCat
import FirebaseAuth
import FirebaseFirestore

enum PaywallVariant {
    case control    // existing PaywallView  (RC offering: "default")
    case treatment  // new PaywallVariantBView (RC offering: AppConfig.Experiments.paywallVariantBOfferingId)
}

/// When a non-subscriber first sees the paywall.
enum PaywallTiming: String, CaseIterable {
    case upfront              // hard paywall right after onboarding (RC offering: "default")
    case afterFirstDiagnosis  // one free diagnosis, steps locked (RC offering: AppConfig.Experiments.paywallAfterDiagnosisOfferingId)
}

@MainActor
@Observable
final class RevenueCatService {

    // MARK: - State

    var purchaseInProgress = false
    var purchaseError: String? = nil
    var paywallVariant: PaywallVariant = .control

    /// Timing assigned by RevenueCat. Read `paywallTiming` instead, which also
    /// honours the DEBUG override.
    private(set) var assignedPaywallTiming: PaywallTiming = .upfront

    #if DEBUG
    private static let timingOverrideKey = "debug.paywallTimingOverride"

    /// DEBUG-only override set from the debug menu (shake the device) or the
    /// launch argument `-debug.paywallTimingOverride afterFirstDiagnosis`.
    var debugPaywallTimingOverride: PaywallTiming? =
        UserDefaults.standard.string(forKey: timingOverrideKey).flatMap(PaywallTiming.init(rawValue:)) {
        didSet {
            UserDefaults.standard.set(debugPaywallTimingOverride?.rawValue, forKey: Self.timingOverrideKey)
        }
    }

    var paywallTiming: PaywallTiming { debugPaywallTimingOverride ?? assignedPaywallTiming }
    #else
    var paywallTiming: PaywallTiming { assignedPaywallTiming }
    #endif

    // MARK: - Offerings / Experiment

    func fetchOfferings() async {
        let offerings: Offerings? = await withCheckedContinuation { continuation in
            Purchases.shared.getOfferings { offerings, _ in
                continuation.resume(returning: offerings)
            }
        }
        let currentId = offerings?.current?.identifier
        // The after-diagnosis test reuses the paywall_v2 design (the current
        // default) so the only difference between its arms is *when* it shows.
        let variantBOfferings = [
            AppConfig.Experiments.paywallVariantBOfferingId,
            AppConfig.Experiments.paywallAfterDiagnosisOfferingId,
        ]
        paywallVariant = variantBOfferings.contains(currentId ?? "") ? .treatment : .control
        assignedPaywallTiming = currentId == AppConfig.Experiments.paywallAfterDiagnosisOfferingId
            ? .afterFirstDiagnosis : .upfront
    }

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

        // Lifetime purchases appear in nonSubscriptionTransactions, not activeSubscriptions
        let activeProductId: String?
        if let pid = productId {
            activeProductId = pid
        } else if let sub = info.activeSubscriptions.first {
            activeProductId = sub
        } else {
            activeProductId = info.nonSubscriptionTransactions.last?.productIdentifier
        }

        let isLifetime = activeProductId?.contains("lifetime") == true
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
        if isLifetime {
            data["hasLifetimeAccess"] = true
            data["credits"] = UserProfile.unlimitedSentinel
            data["billingInterval"] = "lifetime"
        } else if let credits = planInfo?.credits {
            data["credits"] = credits
        }
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
        if id.contains("pro") { return "pro" }
        return nil
    }
}
