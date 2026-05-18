import Foundation

public struct TestGenerator {

    private let client: LLMClient

    public init(apiKey: String, model: String = "mistral-large-latest") {
        self.client = LLMClient(apiKey: apiKey, model: model)
    }

    public struct GeneratedTest {
        public let sourceFile: SwiftSourceFile
        public let code: String
        public let outputFileName: String
    }

    public func generate(
        for file: SwiftSourceFile,
        context: String,
        moduleName: String
    ) async throws -> GeneratedTest {

        let system = """
        You are a senior iOS engineer specialized in Swift, SwiftUI, and XCTest.
        Your task is to generate complete, compilable XCTest files.

        Absolute rules:
        - Write ONLY valid Swift code. No text outside the code.
        - Do not use markdown, backticks, or comments like "here is the code".
        - Start directly with "import XCTest".
        - Tests must compile with Xcode 15+ without modifications.
        - For SwiftUI Views, test the ViewModel or logic, not the View itself.
        - If you need mocks, define them in the same file as Mock* classes/structs.
        - Use @testable import only if the module is testable (not for pure SwiftUI).
        - Test method naming: test_methodName_scenario_expectedResult
        """

        let user = """
        Generate a complete XCTest file for the following Swift code.
        Module: \(moduleName)

        \(context)

        The test file must:
        1. Cover every public method with at least 2 cases (happy path + edge case)
        2. Test boundary values: empty arrays, nil, empty strings, negative values
        3. Use setUp() to initialize the subject under test
        4. For async methods use async throws in the test method
        5. For ObservableObject classes test that @Published properties emit correct values

        Start with: import XCTest
        """

        let raw = try await client.generate(system: system, user: user)
        let clean = stripMarkdown(raw)
        let formatted = formatCode(clean)
        let baseName = file.url.deletingPathExtension().lastPathComponent

        return GeneratedTest(
            sourceFile: file,
            code: formatted,
            outputFileName: "\(baseName)Tests.swift"
        )
    }

    // Rimuove i backtick markdown che LLM a volte aggiunge
    private func stripMarkdown(_ code: String) -> String {
        var lines = code.components(separatedBy: "\n")
        if lines.first?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
            lines.removeFirst()
        }
        if lines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    private func formatCode(_ code: String) -> String {
        var result: [String] = []
        var indentLevel = 0
        let indentUnit = "    " // 4 spazi

        for line in code.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Riga vuota — la teniamo vuota
            if trimmed.isEmpty {
                result.append("")
                continue
            }

            // Riduci indent prima di scrivere le righe che chiudono un blocco
            if trimmed.hasPrefix("}") || trimmed.hasPrefix("]") || trimmed.hasPrefix(")") {
                indentLevel = max(0, indentLevel - 1)
            }

            result.append(String(repeating: indentUnit, count: indentLevel) + trimmed)

            // Aumenta indent dopo le righe che aprono un blocco
            if trimmed.hasSuffix("{") || trimmed.hasSuffix("[") || trimmed.hasSuffix("(") {
                indentLevel += 1
            }

            // Caso speciale: riga che apre e chiude nello stesso giro
            // es: "override func setUp() { super.setUp() }"
            // non deve aumentare il livello
            if trimmed.hasSuffix("{") && trimmed.contains("}") {
                indentLevel = max(0, indentLevel - 1)
            }
        }

        return result.joined(separator: "\n")
    }
}
