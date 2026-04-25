import Foundation

public struct TestGenerator {

    private let client: GPTClient

    public init(apiKey: String, model: String = "gpt-4o") {
        self.client = GPTClient(apiKey: apiKey, model: model)
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
        Sei un senior iOS engineer specializzato in Swift, SwiftUI e XCTest.
        Il tuo compito è generare file di test XCTest completi e compilabili.

        Regole assolute:
        - Scrivi SOLO codice Swift valido. Zero testo fuori dal codice.
        - Non usare markdown, backtick, o commenti tipo "ecco il codice".
        - Inizia direttamente con "import XCTest".
        - I test devono compilare con Xcode 15+ senza modifiche.
        - Per le View SwiftUI testa il ViewModel o la logica, non la View stessa.
        - Se hai bisogno di mock, definiscili nello stesso file come classi/struct Mock*.
        - Usa @testable import solo se il modulo è testabile (non per SwiftUI puri).
        - Naming dei test: test_nomeMetodo_scenario_risultatoAtteso
        """

        let user = """
        Genera un file XCTest per il seguente codice Swift.
        Modulo: \(moduleName)

        \(context)

        Il file di test deve:
        1. Coprire ogni metodo pubblico con almeno 2 casi (happy path + edge case)
        2. Testare valori boundary: array vuoti, nil, stringhe vuote, valori negativi
        3. Usare setUp() per inizializzare il soggetto sotto test
        4. Per metodi async usare async throws nel metodo di test
        5. Per classi ObservableObject testare che @Published emetta i valori corretti

        Inizia con: import XCTest
        """

        let raw = try await client.generate(system: system, user: user)
        let clean = stripMarkdown(raw)
        let baseName = file.url.deletingPathExtension().lastPathComponent

        return GeneratedTest(
            sourceFile: file,
            code: clean,
            outputFileName: "\(baseName)Tests.swift"
        )
    }

    // Rimuove i backtick markdown che GPT a volte aggiunge
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
}
