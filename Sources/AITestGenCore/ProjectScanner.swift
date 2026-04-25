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
}
