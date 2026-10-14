import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore

@MainActor
@Observable
final class RepairViewModel {

    // MARK: - State
    var currentGuide: RepairGuide? = nil
    var isAnalyzing = false
    var errorMessage: String? = nil
    var analysisSeconds: Int = 0

    private var timerTask: Task<Void, Never>?

    // MARK: - Analyze

    /// `freeDiagnosis` asks the backend to spend the account's one free
    /// diagnosis (paywall-after-diagnosis test) when it has no credits.
    func analyze(description: String, image: UIImage?, freeDiagnosis: Bool = false) async {
        let trimmed = description.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty || image != nil else {
            errorMessage = "Please scan an issue or describe the repair."
            return
        }
        let effectiveDescription = trimmed.isEmpty
            ? "Analyze this home repair issue from the attached photo and provide a full repair guide."
            : trimmed

        isAnalyzing = true
        errorMessage = nil
        analysisSeconds = 0
        currentGuide = nil
        startTimer()
        defer { isAnalyzing = false; stopTimer() }

        var body: [String: Any] = ["description": effectiveDescription]

        if let uid = Auth.auth().currentUser?.uid {
            body["uid"] = uid
        }
        if freeDiagnosis {
            body["freeDiagnosis"] = true
        }

        var imageBase64: String? = nil
        if let image = image, let data = compressImage(image) {
            let b64 = "data:image/jpeg;base64,\(data.base64EncodedString())"
            body["image"] = b64
            imageBase64 = data.base64EncodedString()
        }

        do {
            let response: AIAnalyzeResponse = try await APIService.shared.post(
                "/api/ai/analyze",
                body: body,
                requiresAuth: false
            )

            let title = String(effectiveDescription.prefix(120))
            let steps = response.steps.enumerated().map { i, s in
                RepairStep(id: i, description: s)
            }

            var guide = RepairGuide(
                userId: Auth.auth().currentUser?.uid ?? "anonymous",
                title: title,
                steps: steps,
                tools: response.tools,
                materials: response.materials,
                estimatedTime: response.estimatedTime,
                imageAnalysis: response.imageAnalysis,
                confidenceScore: response.confidenceScore,
                imageBase64: imageBase64,
                timestamp: Date()
            )

            currentGuide = guide

            // Save to Firestore — timestamp is a required field per security rules
            if let _ = Auth.auth().currentUser?.uid {
                do {
                    let docRef = try await Firestore.db.collection("repairs").addDocument(
                        data: guide.firestoreData.merging(
                            ["timestamp": FieldValue.serverTimestamp()]
                        ) { _, new in new }
                    )
                    currentGuide?.id = docRef.documentID
                } catch {
                    print("[RepairVM] Firestore save failed: \(error.localizedDescription)")
                }
            }

        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Reset

    func reset() {
        currentGuide = nil
        errorMessage = nil
    }

    // MARK: - Helpers

    private func compressImage(_ image: UIImage, maxWidth: CGFloat = 800, quality: CGFloat = 0.7) -> Data? {
        let scale = min(maxWidth / image.size.width, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    private func startTimer() {
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                analysisSeconds += 1
                if analysisSeconds >= 90 { break }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    var timerDisplay: String {
        let m = analysisSeconds / 60
        let s = analysisSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
