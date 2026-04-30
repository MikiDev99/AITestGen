// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AITestGen",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "aitestgen",
            targets: ["AITestGenTool"]
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
        .target(
            name: "AITestGenCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .executableTarget(
            name: "AITestGenTool",
            dependencies: [
                "AITestGenCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "AITestGenCoreTests",
            dependencies: ["AITestGenCore"]
        ),
    ]
)
