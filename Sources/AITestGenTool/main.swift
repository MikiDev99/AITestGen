import ArgumentParser
import Foundation
import AITestGenCore

@main
struct AITestGenTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aitestgen",
        abstract: "Genera test XCTest per app iOS usando AI",
        version: AITestGenCore.version
    )

    @Option(name: .shortAndLong, help: "Cartella del progetto (default: cartella corrente)")
    var project: String = FileManager.default.currentDirectoryPath

    @Option(name: .long, help: "Modello da usare")
    var model: String = "moonshotai/kimi-k2.6"

    @Option(name: .long, help: "Cartella di output per i test")
    var output: String = ""

    @Flag(name: .shortAndLong, help: "Genera test per tutti i file senza chiedere")
    var all: Bool = false

    mutating func run() throws {
        let apiKey = ProcessInfo.processInfo.environment["NVIDIA_API_KEY"] ?? ""

        guard !apiKey.isEmpty else {
            print("Errore: chiave API mancante.")
            print("Soluzione: export NVIDIA_API_KEY=\"...\" nel tuo ~/.zshrc")
            throw ExitCode.failure
        }
        
        let projectPath = project
        let modelName = model
        let outputPath = output
        let generateAll = all

        let semaphore = DispatchSemaphore(value: 0)
        var generationError: Error? = nil

        Task {
            defer { semaphore.signal() }
            do {
                try await generate(
                    projectPath: projectPath,
                    apiKey: apiKey,
                    model: modelName,
                    output: outputPath,
                    all: generateAll
                )
            } catch {
                generationError = error
            }
        }

        semaphore.wait()

        if let error = generationError {
            print("Errore: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

// Funzione async separata — non cattura self mutabile
private func generate(
    projectPath: String,
    apiKey: String,
    model: String,
    output: String,
    all: Bool
) async throws {
    print("AITestGen v\(AITestGenCore.version)\n")

    let projectURL = URL(fileURLWithPath: projectPath)
    let outputURL: URL
    if !output.isEmpty {
        // L'utente ha specificato --output esplicitamente
        outputURL = URL(fileURLWithPath: output)
    } else {
        // Cerca automaticamente la cartella test del progetto
        print("Ricerca cartella test...")
        outputURL = InteractiveMenu.selectOutputDirectory(projectDirectory: projectURL)
    }

    // 1. Scansione
    print("Scansione progetto...")
    let files = ProjectScanner.scan(projectDirectory: projectURL)
    guard !files.isEmpty else {
        print("Nessun file Swift trovato.")
        return
    }
    print("Trovati \(files.count) file Swift\n")

    // 2. Indice RAG
    print("Costruzione indice dipendenze...")
    let index = try DependencyIndex.build(from: files, projectDirectory: projectURL)
    print("")

    // 3. Selezione file
    let selectedFiles = all ? files : InteractiveMenu.selectFiles(from: files)
    guard !selectedFiles.isEmpty else { return }

    // 4. Crea cartella output
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

    // 5. Genera test
    let generator = TestGenerator(apiKey: apiKey, model: model)
    print("\nGenerazione in corso...\n")

    for (i, file) in selectedFiles.enumerated() {
        print("[\(i+1)/\(selectedFiles.count)] \(file.relativePath)")

        let parsed = try SwiftFileParser.parse(file: file)
        guard !parsed.types.isEmpty else {
            print("  Nessun tipo trovato, salto.\n")
            continue
        }

        let context = try DependencyIndex.buildContext(
            for: file,
            parsedFile: parsed,
            index: index,
            allFiles: files,
            projectDirectory: projectURL
        )

        let depPaths = index.dependencyPaths(for: parsed)
        print("  Tipi: \(parsed.types.count) | Dipendenze RAG: \(depPaths.count) file")
        print("  Chiamata a LLM (\(model))...")

        let result = try await generator.generate(
            for: file,
            context: context,
            moduleName: file.moduleName
        )

        let outURL = outputURL.appendingPathComponent(result.outputFileName)
        try result.code.write(to: outURL, atomically: true, encoding: .utf8)
        print("  Scritto: AIGeneratedTests/\(result.outputFileName)\n")
    }

    print("✓ Completato. Test salvati in: \(outputURL.path)")
    print("")
    print("Prossimi passi:")
    print("  1. Apri Xcode nel tuo progetto")
    print("  2. Lancia i test con Cmd+U")
}
