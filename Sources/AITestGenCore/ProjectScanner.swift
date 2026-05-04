import Foundation

public struct SwiftSourceFile {
    public let url: URL
    public let relativePath: String
    public let moduleName: String
}

public struct ProjectScanner {

    public static func scan(projectDirectory: URL) -> [SwiftSourceFile] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: projectDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [SwiftSourceFile] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            guard !shouldExclude(fileURL) else { continue }

            let relativePath = fileURL.path
                .replacingOccurrences(of: projectDirectory.path + "/", with: "")

            // Il "modulo" è la prima cartella del path relativo
            // es: "Login/LoginViewModel.swift" → modulo "Login"
            let parts = relativePath.components(separatedBy: "/")
            let moduleName = parts.count > 1 ? parts[0] : "App"

            files.append(SwiftSourceFile(
                url: fileURL,
                relativePath: relativePath,
                moduleName: moduleName
            ))
        }

        return files.sorted { $0.relativePath < $1.relativePath }
    }

    private static func shouldExclude(_ url: URL) -> Bool {
        let path = url.path
        let excluded = [
            "Tests/",
            "Test/",
            "Preview Content/",
            "PreviewContent/",
            "Generated/",
            "Pods/",
            ".build/",
            "DerivedData/",
            "AppDelegate.swift",
            "main.swift",
        ]
        return excluded.contains { path.contains($0) }
    }
    
    public static func findTestDirectories(in projectDirectory: URL) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: projectDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var testDirs: [URL] = []

        for case let url as URL in enumerator {
            // Salta la cartella .build e DerivedData
            guard !url.path.contains(".build"),
                  !url.path.contains("DerivedData") else { continue }

            var isDirectory: ObjCBool = false
            fm.fileExists(atPath: url.path, isDirectory: &isDirectory)
            guard isDirectory.boolValue else { continue }

            // Cerca cartelle con "Tests" o "Test" nel nome
            let name = url.lastPathComponent
            guard name.contains("Tests") || name.contains("Test") else { continue }

            // Verifica che contenga almeno un file Swift
            // (esclude cartelle vuote o cartelle UITest se vogliamo)
            let contents = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
            let hasSwift = contents.contains { $0.hasSuffix(".swift") }
            guard hasSwift else { continue }

            // Esclude UITest — non è dove vogliamo scrivere unit test
            guard !name.contains("UITest") else { continue }

            testDirs.append(url)
        }

        return testDirs.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
