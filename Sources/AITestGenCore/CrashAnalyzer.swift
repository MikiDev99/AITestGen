import Foundation

public struct CrashAnalyzer {

    private let client: LLMClient

    public init(apiKey: String, model: String = "moonshotai/kimi-k2.6") {
        self.client = LLMClient(apiKey: apiKey, model: model)
    }

    public struct Analysis {
        public let cause: String
        public let solution: String
        public let affectedFiles: [String]
        public let raw: String
    }

    public func analyze(
        crashLog: ParsedCrashLog,
        sourceContext: String
    ) async throws -> Analysis {

        let system = """
        You are a senior iOS engineer specialized in debugging Swift crashes.
        Analyze Firebase Crashlytics crash logs and return a concise diagnosis.

        Rules:
        - Be extremely concise — maximum 10 lines total.
        - One line for the root cause.
        - List only the affected files with line number and the exact fix inline.
        - Include a minimal code snippet showing the fix, not the full method.
        - No prose, no explanations, no numbered steps.
        - Format your response as JSON with keys: "cause", "solution", "affectedFiles"
        - Write only valid JSON. No markdown, no backticks, no extra text.
        """

        let user = """
        Analyze this iOS crash and return a concise diagnosis.

        ## Crash Summary
        \(crashLog.summary)

        ## Source Code
        \(sourceContext)

        Respond with JSON:
        {
          "cause": "one line — what crashed and why",
          "solution": "file:line → fix\\n// code snippet",
          "affectedFiles": ["File1.swift", "File2.swift"]
        }
        """

        let raw = try await client.generate(system: system, user: user)
        return parseAnalysis(raw: raw)
    }
    
    private func parseAnalysis(raw: String) -> Analysis {
        // Pulisce eventuali backtick markdown
        let clean = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = clean.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Se il JSON non è parsabile restituisce la risposta raw
            return Analysis(
                cause: raw,
                solution: "Could not parse structured response.",
                affectedFiles: [],
                raw: raw
            )
        }

        return Analysis(
            cause: json["cause"] as? String ?? "Unknown cause",
            solution: json["solution"] as? String ?? "No solution provided",
            affectedFiles: json["affectedFiles"] as? [String] ?? [],
            raw: raw
        )
    }
}
