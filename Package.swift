// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MCPSpanCLI",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(
            url: "https://github.com/modelcontextprotocol/swift-sdk.git",
            from: "0.12.0"
        ),
        .package(
            url: "https://github.com/apple/swift-system.git",
            from: "1.0.0"
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.7.1"
        ),
        .package(
            url: "https://github.com/mattt/eventsource.git",
            from: "1.1.0"
        ),
        .package(
            url: "https://github.com/apple/swift-log.git",
            from: "1.5.0"
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "MCPSpanCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "EventSource", package: "eventsource"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "SystemPackage", package: "swift-system")
            ]
        ),

    ],
    swiftLanguageModes: [.v6]
)
