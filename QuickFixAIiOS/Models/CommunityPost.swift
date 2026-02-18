import Foundation

struct CommunityPost: Identifiable, Equatable {
    let id: String           // Firestore document ID
    var title: String
    var category: String
    var description: String
    var author: String
    var authorId: String
    var beforeImage: String  // base64 JPEG
    var afterImage: String   // base64 JPEG
    var tags: [String]
    var likes: Int
    var likedBy: [String]    // array of UIDs
    var timestamp: Date?

    static let categories = [
        "plumbing", "electrical", "hvac", "carpentry",
        "painting", "general", "appliances", "flooring",
        "roofing", "landscaping"
    ]

    var categoryDisplayName: String {
        category.prefix(1).uppercased() + category.dropFirst()
    }

    init?(id: String, data: [String: Any]) {
        guard
            let title       = data["title"] as? String,
            let category    = data["category"] as? String,
            let description = data["description"] as? String,
            let author      = data["author"] as? String,
            let authorId    = data["authorId"] as? String,
            let beforeImage = data["beforeImage"] as? String,
            let afterImage  = data["afterImage"] as? String
        else { return nil }

        self.id          = id
        self.title       = title
        self.category    = category
        self.description = description
        self.author      = author
        self.authorId    = authorId
        self.beforeImage = beforeImage
        self.afterImage  = afterImage
        self.tags        = data["tags"] as? [String] ?? []
        self.likes       = data["likes"] as? Int ?? 0
        self.likedBy     = data["likedBy"] as? [String] ?? []
        self.timestamp   = (data["timestamp"] as? any FirestoreTimestampProtocol)?.dateValue()
    }
}
