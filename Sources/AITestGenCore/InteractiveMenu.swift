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
                print("    \(counter). \(name)")
                indexed.append((counter, file))
                counter += 1
            }
        }

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
}
