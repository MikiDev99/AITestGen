import ArgumentParser
import Foundation
import AITestGenCore

@main
struct AITestGenTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aitestgen",
        abstract: "Generate XCTest unit tests and analyze crashes for iOS projects",
        version: AITestGenCore.version,
        subcommands: [GenerateCommand.self, CrashCommand.self],
        defaultSubcommand: GenerateCommand.self
    )
}

struct GenerateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate XCTest unit tests for Swift files"
    )
    
    @Option(name: .shortAndLong, help: "Project directory (default: current directory)")
    var project: String = FileManager.default.currentDirectoryPath
    
    @Option(name: .long, help: "LLM model to use")
    var model: String = "moonshotai/kimi-k2.6"
    
    @Option(name: .long, help: "Output directory for generated tests")
    var output: String = ""
    
    @Flag(name: .shortAndLong, help: "Generate tests for all files without prompting")
    var all: Bool = false
    
    mutating func run() throws {
        let apiKey = ProcessInfo.processInfo.environment["NVIDIA_API_KEY"] ?? ""
        
        guard !apiKey.isEmpty else {
            print("Error: missing API key.")
            print("Fix: export NVIDIA_API_KEY=\"your-key\" in ~/.zshrc")
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
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct CrashCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "crash",
        abstract: "Analyze a Firebase Crashlytics crash log and generate a reproduction test"
    )
    
    @Option(name: .long, help: "Path to the crash log .txt file")
    var crashLog: String
    
    @Option(name: .shortAndLong, help: "Project directory (default: current directory)")
    var project: String = FileManager.default.currentDirectoryPath
    
    @Option(name: .long, help: "AI model to use")
    var model: String = "moonshotai/kimi-k2.6"
    
    mutating func run() throws {
        let apiKey = ProcessInfo.processInfo.environment["NVIDIA_API_KEY"] ?? ""
        
        guard !apiKey.isEmpty else {
            print("Error: missing API key.")
            print("Fix: export NVIDIA_API_KEY=\"your-key\" in ~/.zshrc")
            throw ExitCode.failure
        }
        
        let crashLogPath = crashLog
        let projectPath = project
        let modelName = model
        
        let semaphore = DispatchSemaphore(value: 0)
        var runError: Error? = nil
        
        Task {
            defer { semaphore.signal() }
            do {
                try await analyzeCrash(
                    crashLogPath: crashLogPath,
                    projectPath: projectPath,
                    apiKey: apiKey,
                    model: modelName
                )
            } catch {
                runError = error
            }
        }
        
        semaphore.wait()
        
        if let error = runError {
            print("Error: \(error.localizedDescription)")
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
        print("Searching test folder...")
        outputURL = InteractiveMenu.selectOutputDirectory(projectDirectory: projectURL)
    }
    
    // 1. Scansione
    print("Scanning project...")
    let files = ProjectScanner.scan(projectDirectory: projectURL)
    guard !files.isEmpty else {
        print("No Swift files found.")
        return
    }
    print("Found \(files.count) Swift files\n")
    
    // 2. Indice RAG
    print("Building dependency index...")
    let index = try DependencyIndex.build(from: files, projectDirectory: projectURL)
    print("")
    
    // 3. Selezione file
    let selectedFiles = all ? files : InteractiveMenu.selectFiles(from: files)
    guard !selectedFiles.isEmpty else { return }
    
    // 4. Crea cartella output
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    
    // 5. Genera test
    let generator = TestGenerator(apiKey: apiKey, model: model)
    print("\nGenerating tests...\n")
    
    for (i, file) in selectedFiles.enumerated() {
        print("[\(i+1)/\(selectedFiles.count)] \(file.relativePath)")
        
        let parsed = try SwiftFileParser.parse(file: file)
        guard !parsed.types.isEmpty else {
            print("  No types found, skipping.\n")
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
        print("  Types: \(parsed.types.count) | RAG dependencies: \(depPaths.count) files")
        print("  Calling LLM model (\(model))...")
        
        let result = try await generator.generate(
            for: file,
            context: context,
            moduleName: file.moduleName
        )
        
        let outURL = outputURL.appendingPathComponent(result.outputFileName)
        try result.code.write(to: outURL, atomically: true, encoding: .utf8)
        print("  Written: \(result.outputFileName)\n")
    }
    
    print("✓ Done. Test saved in: \(outputURL.path)")
    print("")
    print("Next steps:")
    print("  1. Open Xcode in your project")
    print("  2. Run tests with Cmd+U")
}

private func analyzeCrash(
    crashLogPath: String,
    projectPath: String,
    apiKey: String,
    model: String
) async throws {
    print("AITestGen v\(AITestGenCore.version) — Crash Analyzer\n")
    
    let crashURL = URL(fileURLWithPath: crashLogPath)
    let projectURL = URL(fileURLWithPath: projectPath)
    
    // 1. Parsing del crash log
    print("Parsing crash log...")
    let crashLog = try CrashLogParser.parse(fileURL: crashURL)
    
    guard let crashedThread = crashLog.crashedThread else {
        print("No crashed thread found in log.")
        return
    }
    
    print("Crashed thread: \(crashedThread.name)")
    print("Relevant frames: \(crashedThread.relevantFrames.count)")
    print("Source files involved: \(crashedThread.sourceFiles.joined(separator: ", "))\n")
    
    // 2. RAG — trova il codice sorgente dei file coinvolti
    print("Searching source files in project...")
    let allFiles = ProjectScanner.scan(projectDirectory: projectURL)
    let index = try DependencyIndex.build(from: allFiles, projectDirectory: projectURL)
    
    var sourceContext = "## Stack trace\n\(crashLog.summary)\n\n## Source code\n"
    
    for sourceFileName in crashedThread.sourceFiles {
        if let match = allFiles.first(where: {
            $0.url.lastPathComponent == sourceFileName
        }) {
            let source = try String(contentsOf: match.url, encoding: .utf8)
            sourceContext += "\n--- \(sourceFileName) ---\n\(source)\n"
        }
    }
    
    // 3. Analisi LLM
    print("Analyzing crash with AI (\(model))...\n")
    let analyzer = CrashAnalyzer(apiKey: apiKey, model: model)
    let analysis = try await analyzer.analyze(
        crashLog: crashLog,
        sourceContext: sourceContext
    )
    
    // 4. Output analisi
    print("╔════════════════════════════════════════╗")
    print("║           Crash Analysis               ║")
    print("╚════════════════════════════════════════╝\n")
    print("ROOT CAUSE:")
    print(analysis.cause)
    print("")
    print("SOLUTION:")
    print(analysis.solution)
    print("")
    
    if !analysis.affectedFiles.isEmpty {
        print("AFFECTED FILES:")
        analysis.affectedFiles.forEach { print("  • \($0)") }
        print("")
    }
    
    // 5. Chiede se generare test di riproduzione
//    print("Generate a reproduction test for this crash? [Y/n]: ", terminator: "")
//    let input = readLine()?.trimmingCharacters(in: .whitespaces).lowercased() ?? "y"
//    
//    guard input != "n" else {
//        print("Done.")
//        return
//    }
//    
//    // 6. Genera test di riproduzione usando il TestGenerator esistente
//    print("\nGenerating reproduction test...\n")
//    
//    let outputURL = InteractiveMenu.selectOutputDirectory(projectDirectory: projectURL)
//    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
//    
//    let generator = TestGenerator(apiKey: apiKey, model: model)
//    
//    for sourceFileName in crashedThread.sourceFiles {
//        guard let file = allFiles.first(where: {
//            $0.url.lastPathComponent == sourceFileName
//        }) else { continue }
//        
//        let parsed = try SwiftFileParser.parse(file: file)
//        let context = try DependencyIndex.buildContext(
//            for: file,
//            parsedFile: parsed,
//            index: index,
//            allFiles: allFiles,
//            projectDirectory: projectURL
//        )
//        
//        // Contesto arricchito con l'analisi del crash
//        let enrichedContext = """
//        \(context)
//        
//        ## Crash context
//        This file was involved in a crash. The analysis says:
//        Cause: \(analysis.cause)
//        Solution: \(analysis.solution)
//        
//        Generate a test that reproduces the crash scenario and verifies the fix.
//        """
//        
//        let result = try await generator.generate(
//            for: file,
//            context: enrichedContext,
//            moduleName: file.moduleName
//        )
//        
//        let outURL = outputURL.appendingPathComponent("CrashRepro_\(result.outputFileName)")
//        try result.code.write(to: outURL, atomically: true, encoding: .utf8)
//        print("  Written: CrashRepro_\(result.outputFileName)\n")
//    }
    
    print("✓ Analysis complete.")
    print("Run 'aitestgen' in your project to generate tests for the affected files.")
//    print("✓ Done.")
//    print("Next steps:")
//    print("  1. Add the CrashRepro_* files to your test target in Xcode")
//    print("  2. Run tests with Cmd+U to verify the fix")
}
