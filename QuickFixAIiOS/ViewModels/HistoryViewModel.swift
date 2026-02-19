import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
@Observable
final class HistoryViewModel {

    // MARK: - State
    var repairs: [RepairGuide] = []
    var isLoading = false
    var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    // MARK: - Load repairs for current user

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        stopListening()
        isLoading = true

        listener = Firestore.db.collection("repairs")
            .whereField("userId", isEqualTo: uid)
            .addSnapshotListener { [weak self] snap, error in
                Task { @MainActor [weak self] in
                    self?.isLoading = false
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    // Sort client-side — avoids needing a composite Firestore index
                    self?.repairs = (snap?.documents.compactMap {
                        RepairGuide(id: $0.documentID, data: $0.data())
                    } ?? []).sorted {
                        ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast)
                    }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Delete

    func delete(repair: RepairGuide) async {
        guard !repair.id.isEmpty else { return }
        do {
            try await Firestore.db.collection("repairs").document(repair.id).delete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Cap check (frontend-enforced)

    func isAtHistoryCap(for plan: SubscriptionPlan) -> Bool {
        guard let cap = plan.historyCap else { return false }
        return repairs.count >= cap
    }
}
