import Foundation
import FirebaseAuth

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case httpError(Int, String)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid URL."
        case .noData:              return "No data received from server."
        case .httpError(let code, let msg): return "Server error \(code): \(msg)"
        case .decodingError(let e):return "Failed to decode response: \(e.localizedDescription)"
        case .networkError(let e): return e.localizedDescription
        case .unauthorized:        return "Not authorized. Please sign in again."
        }
    }
}

// MARK: - API Service

final class APIService {
    static let shared = APIService()
    private let baseURL: String

    private init() {
        self.baseURL = AppConfig.apiBaseURL
    }

    // MARK: - Auth token helper

    private func authToken() async throws -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        return try await user.getIDToken()
    }

    // MARK: - Base request builder

    private func makeRequest(
        method: String,
        path: String,
        body: [String: Any]? = nil,
        requiresAuth: Bool = false
    ) async throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90

        if requiresAuth {
            guard let token = try await authToken() else { throw APIError.unauthorized }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let token = try? await authToken() {
            // Attach token opportunistically for optional-auth endpoints
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    // MARK: - Generic execute

    private func execute(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }

        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["message"] as? String ?? $0["error"] as? String } ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.httpError(http.statusCode, msg)
        }
        return data
    }

    // MARK: - Public methods

    func post<T: Decodable>(
        _ path: String,
        body: [String: Any] = [:],
        requiresAuth: Bool = false
    ) async throws -> T {
        let req = try await makeRequest(method: "POST", path: path, body: body, requiresAuth: requiresAuth)
        let data = try await execute(req)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func post(
        _ path: String,
        body: [String: Any] = [:],
        requiresAuth: Bool = false
    ) async throws {
        let req = try await makeRequest(method: "POST", path: path, body: body, requiresAuth: requiresAuth)
        _ = try await execute(req)
    }

    func get<T: Decodable>(
        _ path: String,
        requiresAuth: Bool = false
    ) async throws -> T {
        let req = try await makeRequest(method: "GET", path: path, requiresAuth: requiresAuth)
        let data = try await execute(req)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func patch<T: Decodable>(
        _ path: String,
        body: [String: Any] = [:],
        requiresAuth: Bool = false
    ) async throws -> T {
        let req = try await makeRequest(method: "PATCH", path: path, body: body, requiresAuth: requiresAuth)
        let data = try await execute(req)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func delete(
        _ path: String,
        requiresAuth: Bool = false
    ) async throws {
        let req = try await makeRequest(method: "DELETE", path: path, requiresAuth: requiresAuth)
        _ = try await execute(req)
    }

    // MARK: - Multipart (feedback screenshots)

    func postMultipart(
        _ path: String,
        fields: [String: String],
        images: [(data: Data, fieldName: String, filename: String)],
        requiresAuth: Bool = false
    ) async throws {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = try? await authToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        for img in images {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(img.fieldName)\"; filename=\"\(img.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(img.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        _ = try await execute(request)
    }
}
