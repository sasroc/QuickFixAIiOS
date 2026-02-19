import Foundation

// MARK: - RepairStep

struct RepairStep: Identifiable, Codable, Equatable {
    var id: Int           // 0-based index used as stable identity
    var description: String
    var image: String?    // base64 JPEG or nil
}

// MARK: - RepairGuide

struct RepairGuide: Identifiable, Equatable {
    var id: String        // Firestore document ID (empty if not saved yet)
    let userId: String
    let title: String
    var steps: [RepairStep]
    let tools: [String]
    let materials: [String]
    let estimatedTime: Int   // minutes
    let imageAnalysis: String?
    let confidenceScore: Int?
    let imageBase64: String? // original image stored with repair
    let timestamp: Date?

    // MARK: Init from AI response + auth uid

    init(
        id: String = "",
        userId: String,
        title: String,
        steps: [RepairStep],
        tools: [String],
        materials: [String],
        estimatedTime: Int,
        imageAnalysis: String? = nil,
        confidenceScore: Int? = nil,
        imageBase64: String? = nil,
        timestamp: Date? = nil
    ) {
        self.id              = id
        self.userId          = userId
        self.title           = title
        self.steps           = steps
        self.tools           = tools
        self.materials       = materials
        self.estimatedTime   = estimatedTime
        self.imageAnalysis   = imageAnalysis
        self.confidenceScore = confidenceScore
        self.imageBase64     = imageBase64
        self.timestamp       = timestamp
    }

    // MARK: Init from Firestore document data

    init?(id: String, data: [String: Any]) {
        guard let userId = data["userId"] as? String else { return nil }
        self.id     = id
        self.userId = userId
        self.title  = data["title"] as? String ?? "Repair Guide"

        // Steps stored as array of dicts
        if let rawSteps = data["steps"] as? [[String: Any]] {
            self.steps = rawSteps.enumerated().map { idx, s in
                RepairStep(
                    id: idx,
                    description: s["description"] as? String ?? "",
                    image: s["image"] as? String
                )
            }
        } else {
            self.steps = []
        }

        self.tools         = data["tools"] as? [String] ?? []
        self.materials     = data["materials"] as? [String] ?? []
        self.imageAnalysis = data["imageAnalysis"] as? String
        self.imageBase64   = data["imageBase64"] as? String

        if let et = data["estimatedTime"] as? Int {
            self.estimatedTime = et
        } else if let ets = data["estimatedTime"] as? String, let n = Int(ets) {
            self.estimatedTime = n
        } else {
            self.estimatedTime = 0
        }

        if let cs = data["confidenceScore"] as? Int {
            self.confidenceScore = cs
        } else {
            self.confidenceScore = nil
        }

        self.timestamp = (data["timestamp"] as? any FirestoreTimestampProtocol)?.dateValue()
    }

    // MARK: Convert to Firestore dict

    var firestoreData: [String: Any] {
        var d: [String: Any] = [
            "userId":        userId,
            "title":         title,
            "tools":         tools,
            "materials":     materials,
            // Security rules require estimatedTime as a String (matches web: "45 minutes")
            "estimatedTime": "\(estimatedTime) minutes"
        ]
        // Steps: only write description — image field is iOS-only and not in schema
        d["steps"] = steps.map { ["description": $0.description] }
        if let ia = imageAnalysis   { d["imageAnalysis"]   = ia }
        if let cs = confidenceScore { d["confidenceScore"] = cs }
        // imageBase64 intentionally omitted — not in Firestore security rule schema
        return d
    }
}

// MARK: - AI API response shape

struct AIAnalyzeResponse: Decodable {
    let steps: [String]
    let tools: [String]
    let materials: [String]
    let estimatedTime: Int
    let confidenceScore: Int?
    let imageAnalysis: String?
}
