// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AITestGen",
    platforms: [.macOS(.v13)],
    products: [
        // L'eseguibile CLI (per chi vuole usarlo senza Xcode)
        .executable(
            name: "aitestgen",
            targets: ["AITestGenTool"]
        ),
        // Il plugin (per chi lo aggiunge come dipendenza in Xcode)
        .plugin(
            name: "AITestGenPlugin",
            targets: ["AITestGenPlugin"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-syntax.git",
            from: "600.0.0"
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.3.0"
        ),
    ],
    targets: [
        // Logica condivisa — invariata
        .target(
            name: "AITestGenCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        // Eseguibile CLI — rinominato da AITestGenCLI
        .executableTarget(
            name: "AITestGenTool",
            dependencies: [
                "AITestGenCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        // Plugin Xcode — nuovo
        .plugin(
            name: "AITestGenPlugin",
            capability: .command(
                intent: .custom(
                    verb: "generate-ai-tests",
                    description: "Genera test XCTest con AI per i file Swift del progetto"
                ),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "Scrive i file di test generati nella cartella AIGeneratedTests"
                    ),
                ]
            ),
            dependencies: ["AITestGenTool"]
        ),
        // Test del tool — invariati
        .testTarget(
            name: "AITestGenCoreTests",
            dependencies: ["AITestGenCore"]
        ),
    ]
)
