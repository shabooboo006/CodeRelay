// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CodeRelay",
    platforms: [
        .macOS("15.0"),
    ],
    products: [
        .executable(name: "CodeRelayApp", targets: ["CodeRelayApp"]),
        .library(name: "CodeRelayCore", targets: ["CodeRelayCore"]),
        .library(name: "CodeRelayCodex", targets: ["CodeRelayCodex"]),
    ],
    targets: [
        .executableTarget(
            name: "CodeRelayApp",
            dependencies: [
                "CodeRelayCore",
                "CodeRelayCodex",
            ],
            path: "Sources/CodeRelayApp"
        ),
        .target(
            name: "CodeRelayCore",
            path: "Sources/CodeRelayCore"
        ),
        .target(
            name: "CodeRelayCodex",
            dependencies: ["CodeRelayCore"],
            path: "Sources/CodeRelayCodex"
        ),
        .testTarget(
            name: "CodeRelayCoreTests",
            dependencies: ["CodeRelayCore"],
            path: "Tests/CodeRelayCoreTests"
        ),
        .testTarget(
            name: "CodeRelayCodexTests",
            dependencies: [
                "CodeRelayCore",
                "CodeRelayCodex",
            ],
            path: "Tests/CodeRelayCodexTests"
        ),
        .testTarget(
            name: "CodeRelayAppTests",
            dependencies: [
                "CodeRelayApp",
                "CodeRelayCore",
                "CodeRelayCodex",
            ],
            path: "Tests/CodeRelayAppTests"
        ),
    ]
)
