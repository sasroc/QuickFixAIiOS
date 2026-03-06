import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore

@MainActor
@Observable
final class UserViewModel {

    // MARK: - State
    var profile: UserProfile? = nil
    var profileLoaded = false   // true after first Firestore response (doc may or may not exist)
    var isLoading = false
    var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    // MARK: - Computed
    var hasActiveAccess: Bool    { profile?.hasActiveAccess ?? false }
    var credits: Int             { profile?.credits ?? 0 }
    var plan: SubscriptionPlan   { profile?.plan ?? .none }
    var isAdmin: Bool            { profile?.isAdmin ?? false }
    var isAppleSubscriber: Bool  { profile?.isAppleSubscriber ?? false }
    // Optimistic local set — merged with Firestore profile so blocks take effect instantly
    private var locallyBlockedUsers: Set<String> = []
    var blockedUsers: [String] {
        let fromProfile = Set(profile?.blockedUsers ?? [])
        return Array(fromProfile.union(locallyBlockedUsers))
    }

    // MARK: - Start/stop listening to user document

    func startListening(uid: String) {
        stopListening()
        listener = Firestore.db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snap, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.profile = snap?.data().map { UserProfile(uid: uid, data: $0) }
                    self.profileLoaded = true
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        profile = nil
        profileLoaded = false
        locallyBlockedUsers = []
    }

    // MARK: - Block / unblock users

    func blockUser(uid blockedUID: String, postId: String? = nil, postTitle: String? = nil) async {
        // Instant optimistic update — posts vanish from feed before Firestore confirms
        locallyBlockedUsers.insert(blockedUID)

        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        do {
            try await Firestore.db.collection("users").document(currentUID).updateData([
                "blockedUsers": FieldValue.arrayUnion([blockedUID])
            ])
            var reportData: [String: Any] = [
                "type":        "block",
                "reportedBy":  currentUID,
                "blockedUser": blockedUID,
                "timestamp":   FieldValue.serverTimestamp()
            ]
            if let postId    = postId    { reportData["postId"]    = postId }
            if let postTitle = postTitle { reportData["postTitle"] = postTitle }
            try? await Firestore.db.collection("community_reports").addDocument(data: reportData)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Update display name (delegated to AuthViewModel, but exposed here too)

    func updateDisplayName(_ name: String, uid: String) async -> Bool {
        do {
            try await Firestore.db.collection("users").document(uid).updateData([
                "displayName": name,
                "updatedAt":   FieldValue.serverTimestamp()
            ])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Stripe: open checkout

    struct CheckoutURLResponse: Decodable { let url: String }
    struct PortalURLResponse: Decodable   { let url: String }

    func createCheckoutURL(plan: String, billing: String, isTrial: Bool = false) async -> URL? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        isLoading = true
        defer { isLoading = false }
        do {
            let endpoint = isTrial ? "/api/stripe/start-trial" : "/api/stripe/subscribe"
            let body: [String: Any] = [
            "uid": uid,
            "plan": plan,
            "billing": billing,
            "isTrial": isTrial,
            "successUrl": AppConfig.stripeSuccessURL,
            "cancelUrl": AppConfig.stripeCancelURL
        ]
            let response: CheckoutURLResponse = try await APIService.shared.post(endpoint, body: body)
            return URL(string: response.url)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func createPortalURL() async -> URL? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        isLoading = true
        defer { isLoading = false }
        do {
            let response: PortalURLResponse = try await APIService.shared.post(
                "/api/stripe/create-portal-session",
                body: ["uid": uid],
                requiresAuth: true
            )
            return URL(string: response.url)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Apple IAP

    /// Opens the system subscription management page for Apple subscribers.
    func openAppleSubscriptionManagement() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Refund

    struct RefundEligibility: Decodable {
        let eligible: Bool
        let reason: String?
    }

    func checkRefundEligibility() async -> RefundEligibility? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return try? await APIService.shared.get(
            "/api/stripe/refund-eligibility/\(uid)",
            requiresAuth: true
        )
    }

    func requestRefund() async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        isLoading = true
        defer { isLoading = false }
        do {
            try await APIService.shared.post(
                "/api/stripe/refund",
                body: ["uid": uid],
                requiresAuth: true
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
