// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "LaunchDeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LaunchDeck", targets: ["LaunchDeck"])
    ],
    targets: [
        .executableTarget(
            name: "LaunchDeck",
            path: "Sources/LaunchDeck"
        ),
        .testTarget(
            name: "LaunchDeckTests",
            dependencies: ["LaunchDeck"],
            path: "Tests/LaunchDeckTests"
        )
    ]
)
