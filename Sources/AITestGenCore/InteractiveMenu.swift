import Foundation

public struct InteractiveMenu {

    public static func selectFiles(from files: [SwiftSourceFile]) -> [SwiftSourceFile] {
        let grouped = Dictionary(grouping: files, by: \.moduleName)
        var indexed: [(Int, SwiftSourceFile)] = []
        var counter = 1

        print("╔════════════════════════════════════════╗")
        print("║     AITestGen — Scegli i file          ║")
        print("╚════════════════════════════════════════╝\n")

        for module in grouped.keys.sorted() {
            print("  [\(module)]")
            for file in grouped[module]!.sorted(by: { $0.relativePath < $1.relativePath }) {
                let name = file.url.deletingPathExtension().lastPathComponent
                let parsed = try? SwiftFileParser.parse(file: file)
                let testableCount = parsed?.testableTypes.count ?? 0
                let totalCount = parsed?.types.count ?? 0

                let label: String
                if testableCount == 0 {
                    label = " ⚠️  nessun tipo testabile"
                } else if testableCount < totalCount {
                    label = " (\(testableCount)/\(totalCount) tipi testabili)"
                } else {
                    label = ""
                }

                print("    \(counter). \(name)\(label)")
                indexed.append((counter, file))
                counter += 1
            }
        }

        print("")
        print("  ⚠️  = file senza tipi testabili, consigliato saltare")
        print("")
        print("  Opzioni:")
        print("    • Numero singolo:       1")
        print("    • Più numeri:           1,3")
        print("    • Intervallo:           1-3")
        print("    • Tutti:                all")
        print("")
        print("  Selezione: ", terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespaces),
              !input.isEmpty else {
            print("Nessuna selezione.")
            return []
        }

        return parseSelection(input, from: indexed)
    }
    private static func parseSelection(
        _ input: String,
        from indexed: [(Int, SwiftSourceFile)]
    ) -> [SwiftSourceFile] {

        if input.lowercased() == "all" {
            return indexed.map(\.1)
        }

        var selected = Set<Int>()

        for part in input.split(separator: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("-") {
                let bounds = trimmed.split(separator: "-").compactMap { Int($0) }
                if bounds.count == 2 {
                    (bounds[0]...bounds[1]).forEach { selected.insert($0) }
                }
            } else if let n = Int(trimmed) {
                selected.insert(n)
            }
        }

        return indexed
            .filter { selected.contains($0.0) }
            .map(\.1)
    }
    
    public static func selectOutputDirectory(
        projectDirectory: URL
    ) -> URL {
        let testDirs = ProjectScanner.findTestDirectories(in: projectDirectory)
        let fallback = projectDirectory.appendingPathComponent("AIGeneratedTests")

        // Nessuna cartella test trovata — usa fallback
        guard !testDirs.isEmpty else {
            print("  Nessuna cartella test trovata.")
            print("  I test verranno scritti in: AIGeneratedTests/")
            print("  Ricorda di aggiungerla manualmente al test target in Xcode.\n")
            return fallback
        }

        // Una sola cartella trovata — chiede conferma
        if testDirs.count == 1 {
            let dir = testDirs[0]
            let name = dir.lastPathComponent
            print("  Cartella test trovata: \(name)/")
            print("  Scrivo i test qui? [Y/n]: ", terminator: "")

            let input = readLine()?.trimmingCharacters(in: .whitespaces).lowercased() ?? "y"
            if input == "n" {
                print("  I test verranno scritti in: AIGeneratedTests/\n")
                return fallback
            }
            print("")
            return dir
        }

        // Più cartelle trovate — mostra menu
        print("  Trovate più cartelle test:\n")
        for (i, dir) in testDirs.enumerated() {
            print("    \(i + 1). \(dir.lastPathComponent)/")
        }
        print("    \(testDirs.count + 1). Crea AIGeneratedTests/ (nuova cartella)")
        print("")
        print("  Dove scrivo i test? ", terminator: "")

        let input = readLine()?.trimmingCharacters(in: .whitespaces) ?? "1"
        if let n = Int(input), n >= 1, n <= testDirs.count {
            print("")
            return testDirs[n - 1]
        }

        print("  I test verranno scritti in: AIGeneratedTests/\n")
        return fallback
    }
}
