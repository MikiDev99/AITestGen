import Foundation

public struct TestGenerator {

    private let client: LLMClient

    public init(apiKey: String, model: String = "moonshotai/kimi-k2.6") {
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
        - Tests must compile with Xcode 15+ without modifications.
        - For SwiftUI Views, test the ViewModel or logic, not the View itself.
        - If you need mocks, define them in the same file as Mock* classes/structs.
        - Use @testable import only if the module is testable (not for pure SwiftUI).
        - Test method naming: test_methodName_scenario_expectedResult
        - Be concise: max 3 test methods per function, no redundant comments.
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

        MUST FOLLOW RULES:
        - Write clean, concise code — no redundant comments or unnecessary test methods
        - Verify syntax correctness before replying
        - Do not assign to let properties after initialization
        - If you use XCTAssertLessThan, XCTAssertGreaterThan or similar, ensure the type conforms to Comparable — use .rawValue if needed
        - If you use XCTAssertEqual or XCTAssertNotEqual, ensure the type conforms to Equatable
        - Do not declare variables as var unless you explicitly mutate them after initialization.
        - Never use trailing closure syntax with forEach or map when the body spans multiple lines. Use a for-in loop instead.
        - For any method that manipulates strings, test all whitespace variants: 
          spaces, tabs, newlines (\n, \r, \r\n)
        - For any method with numeric boundaries, test: zero, negative values, 
          minimum valid, maximum valid, minimum+1 over maximum
        - For any method that accepts collections, test: empty, single element, 
          multiple elements
        - Generate runnable code that requires zero modifications
        - Start with: import XCTest
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

        // Rimuove righe introduttive prima del codice Swift
        if let firstCodeLine = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("import") ||
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }) {
            lines = Array(lines[firstCodeLine...])
        }

        // Rimuove backtick markdown
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
