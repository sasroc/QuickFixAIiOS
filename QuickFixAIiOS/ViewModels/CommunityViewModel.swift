import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore

@MainActor
@Observable
final class CommunityViewModel {

    // MARK: - State
    var posts: [CommunityPost] = []
    var isLoading = false
    var isSubmitting = false
    var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    // MARK: - Lifecycle

    func startListening() {
        stopListening()
        isLoading = true

        listener = Firestore.db.collection("community_posts")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snap, error in
                Task { @MainActor [weak self] in
                    self?.isLoading = false
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    self?.posts = snap?.documents.compactMap {
                        CommunityPost(id: $0.documentID, data: $0.data())
                    } ?? []
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Filtered / Sorted

    func filtered(category: String, myPostsOnly: Bool, uid: String?) -> [CommunityPost] {
        posts.filter { post in
            let categoryMatch = category == "all" || post.category == category
            let myPostMatch   = !myPostsOnly || post.authorId == uid
            return categoryMatch && myPostMatch
        }
    }

    func sorted(_ posts: [CommunityPost], by sort: CommunitySortOption) -> [CommunityPost] {
        switch sort {
        case .recent:  return posts.sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
        case .popular: return posts.sorted { $0.likes > $1.likes }
        }
    }

    // MARK: - Like / Unlike

    func toggleLike(postId: String, currentUID: String) async {
        let ref = Firestore.db.collection("community_posts").document(postId)
        guard let post = posts.first(where: { $0.id == postId }) else { return }

        if post.likedBy.contains(currentUID) {
            try? await ref.updateData([
                "likes":   FieldValue.increment(Int64(-1)),
                "likedBy": FieldValue.arrayRemove([currentUID])
            ])
        } else {
            try? await ref.updateData([
                "likes":   FieldValue.increment(Int64(1)),
                "likedBy": FieldValue.arrayUnion([currentUID])
            ])
        }
    }

    // MARK: - Create Post

    func createPost(
        title: String,
        category: String,
        description: String,
        tags: [String],
        beforeImage: UIImage,
        afterImage: UIImage,
        authorDisplayName: String,
        authorId: String
    ) async -> Bool {
        guard
            let beforeData = compressImage(beforeImage),
            let afterData  = compressImage(afterImage)
        else {
            errorMessage = "Failed to process images."
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let data: [String: Any] = [
            "title":       title,
            "category":    category,
            "description": description,
            "author":      authorDisplayName,
            "authorId":    authorId,
            "beforeImage": "data:image/jpeg;base64,\(beforeData.base64EncodedString())",
            "afterImage":  "data:image/jpeg;base64,\(afterData.base64EncodedString())",
            "tags":        tags,
            "likes":       0,
            "likedBy":     [String](),
            "timestamp":   FieldValue.serverTimestamp()
        ]

        do {
            try await Firestore.db.collection("community_posts").addDocument(data: data)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Delete Post

    func deletePost(postId: String) async {
        do {
            try await Firestore.db.collection("community_posts").document(postId).delete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Image compression

    private func compressImage(_ image: UIImage, maxWidth: CGFloat = 800, quality: CGFloat = 0.7) -> Data? {
        let scale = min(maxWidth / image.size.width, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

// MARK: - Sort option

enum CommunitySortOption: String, CaseIterable {
    case recent  = "Most Recent"
    case popular = "Most Popular"
}
