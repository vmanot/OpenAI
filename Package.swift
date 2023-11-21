// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "OpenAI",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "OpenAI",
            targets: ["OpenAI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/PreternaturalAI/LargeLanguageModels.git", branch: "main"),
        .package(url: "https://github.com/vmanot/CorePersistence.git", branch: "main"),
        .package(url: "https://github.com/vmanot/NetworkKit.git", branch: "master"),
        .package(url: "https://github.com/vmanot/Swallow.git", branch: "master")
    ],
    targets: [
        .target(
            name: "OpenAI",
            dependencies: [
                "CorePersistence",
                "LargeLanguageModels",
                "NetworkKit",
                "Swallow"
            ]
        ),
        .testTarget(
            name: "OpenAITests",
            dependencies: [
                "OpenAI"
             ]
        )
    ]
)
