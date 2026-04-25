import Foundation

// Una voce nell'indice: un tipo e dove si trova
public struct IndexEntry: Codable {
    public let typeName: String
    public let keyword: String       // struct, class, enum, actor
    public let filePath: String      // path relativo es. "Prova/ContentView.swift"
    public let protocols: [String]
    public let methodNames: [String]
}

// L'indice completo del progetto
public struct ProjectIndex: Codable {
    public let entries: [IndexEntry]
    public let builtAt: Date

    // Dato un ParsedFile, trova i path dei file che contengono
    // i tipi da cui dipende
    public func dependencyPaths(for parsedFile: ParsedFile) -> [String] {
        let referencedNames = parsedFile.referencedTypeNames
        let sourceFile = parsedFile.url.lastPathComponent

        return entries
            .filter { entry in
                referencedNames.contains(entry.typeName) &&
                !entry.filePath.hasSuffix(sourceFile)
            }
            .map(\.filePath)
            // Rimuove duplicati mantenendo l'ordine
            .reduce(into: [String]()) { result, path in
                if !result.contains(path) { result.append(path) }
            }
    }
}

public struct DependencyIndex {

    // Costruisce l'indice da zero (o lo carica dalla cache)
    public static func build(
        from files: [SwiftSourceFile],
        projectDirectory: URL
    ) throws -> ProjectIndex {
        // Controlla se esiste una cache recente (meno di 5 minuti)
        let cacheURL = projectDirectory.appendingPathComponent(".aitestgen_cache.json")
        if let cached = loadCache(from: cacheURL) {
            return cached
        }

        print("  Costruzione indice...")
        var entries: [IndexEntry] = []

        for file in files {
            guard let parsed = try? SwiftFileParser.parse(file: file) else { continue }
            for type_ in parsed.types {
                entries.append(IndexEntry(
                    typeName: type_.name,
                    keyword: type_.keyword,
                    filePath: file.relativePath,
                    protocols: type_.protocols,
                    methodNames: type_.methods.map(\.name)
                ))
            }
        }

        let index = ProjectIndex(entries: entries, builtAt: Date())
        saveCache(index, to: cacheURL)
        print("  Indice costruito: \(entries.count) tipi in \(files.count) file")
        return index
    }

    // Costruisce il testo di contesto da passare a GPT
    // Contiene: il file target + i file delle sue dipendenze
    public static func buildContext(
        for targetFile: SwiftSourceFile,
        parsedFile: ParsedFile,
        index: ProjectIndex,
        allFiles: [SwiftSourceFile],
        projectDirectory: URL,
        maxDependencies: Int = 3
    ) throws -> String {
        var parts: [String] = []

        // 1. Il file che vogliamo testare
        let targetSource = try String(contentsOf: targetFile.url, encoding: .utf8)
        parts.append("""
        === FILE DA TESTARE: \(targetFile.relativePath) ===
        \(targetSource)
        """)

        // 2. Le dipendenze trovate dal RAG
        let depPaths = index.dependencyPaths(for: parsedFile)
        let limitedPaths = Array(depPaths.prefix(maxDependencies))

        if !limitedPaths.isEmpty {
            parts.append("=== TIPI CORRELATI NEL PROGETTO ===")
            for depPath in limitedPaths {
                guard let depFile = allFiles.first(where: { $0.relativePath == depPath }) else { continue }
                let depSource = try String(contentsOf: depFile.url, encoding: .utf8)
                // Prendiamo solo le prime 60 righe per non sprecare token
                let preview = depSource
                    .components(separatedBy: "\n")
                    .prefix(60)
                    .joined(separator: "\n")
                parts.append("""
                --- \(depPath) ---
                \(preview)
                """)
            }
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Cache

    private static func loadCache(from url: URL) -> ProjectIndex? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let index = try? JSONDecoder().decode(ProjectIndex.self, from: data)
        else { return nil }

        // Controlla se la cache è più vecchia di qualsiasi file Swift scansionato
        guard let cacheDate = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                                      .contentModificationDate
        else { return nil }

        let fm = FileManager.default
        let cacheDir = url.deletingLastPathComponent()

        guard let enumerator = fm.enumerator(
            at: cacheDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            guard let modDate = try? fileURL.resourceValues(
                forKeys: [.contentModificationDateKey]
            ).contentModificationDate else { continue }

            // Se anche un solo file Swift è più recente della cache → invalida
            if modDate > cacheDate {
                print("  Cache invalidata: \(fileURL.lastPathComponent) modificato di recente")
                return nil
            }
        }

        print("  Indice caricato dalla cache (\(index.entries.count) tipi)")
        return index
    }

    private static func saveCache(_ index: ProjectIndex, to url: URL) {
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? data.write(to: url)
    }
}
