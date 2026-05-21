import Foundation

public struct LLMClient {

    private let apiKey: String
    private let model: String

    public init(apiKey: String, model: String = "moonshotai/kimi-k2.6") {
        self.apiKey = apiKey
        self.model = model
    }

    public func generate(system: String, user: String) async throws -> String {
        let url = URL(string: "https://integrate.api.nvidia.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let raw = String(data: data, encoding: .utf8) ?? "?"
            throw LLMError.apiError(statusCode: http.statusCode, body: raw)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw LLMError.unexpectedFormat
        }

        return content
    }
}

public enum LLMError: Error, LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, body: String)
    case unexpectedFormat

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Risposta HTTP non valida"
        case .apiError(let code, let body):
            return "Errore API (\(code)): \(body)"
        case .unexpectedFormat:
            return "Formato risposta inatteso"
        }
    }
}
