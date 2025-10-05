// swift-tools-version: 5.9
// ABOUTME: Root package manifest for Vaalin modular Swift Package Manager architecture

import PackageDescription

let package = Package(
    name: "Vaalin",
    platforms: [
        .macOS(.v14) // macOS 26.0 requires minimum of macOS 14 (Sonoma)
    ],
    products: [
        // Main macOS application
        .executable(
            name: "Vaalin",
            targets: ["Vaalin"]
        ),
        // Test executable for manual Lich connection testing
        .executable(
            name: "TestLichConnection",
            targets: ["TestLichConnection"]
        ),
        // Parser library for XML streaming
        .library(
            name: "VaalinParser",
            targets: ["VaalinParser"]
        ),
        // Network library for Lich TCP connection
        .library(
            name: "VaalinNetwork",
            targets: ["VaalinNetwork"]
        ),
        // Core utilities and models
        .library(
            name: "VaalinCore",
            targets: ["VaalinCore"]
        )
    ],
    dependencies: [
        // No external dependencies yet
    ],
    targets: [
        // Main application target
        .executableTarget(
            name: "Vaalin",
            dependencies: [
                "VaalinParser",
                "VaalinNetwork",
                "VaalinCore"
            ],
            path: "Vaalin",
            exclude: [
                "Vaalin.entitlements" // Build config, not a source file
            ],
            resources: [
                .process("Assets.xcassets")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Test executable for manual Lich connection testing
        .executableTarget(
            name: "TestLichConnection",
            dependencies: [
                "VaalinNetwork",
                "VaalinParser",
                "VaalinCore"
            ],
            path: "TestTools/TestLichConnection",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Parser package
        .target(
            name: "VaalinParser",
            dependencies: ["VaalinCore"],
            path: "VaalinParser/Sources/VaalinParser",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "VaalinParserTests",
            dependencies: ["VaalinParser"],
            path: "VaalinParser/Tests/VaalinParserTests"
        ),

        // Network package
        .target(
            name: "VaalinNetwork",
            dependencies: ["VaalinCore"],
            path: "VaalinNetwork/Sources/VaalinNetwork",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "VaalinNetworkTests",
            dependencies: ["VaalinNetwork"],
            path: "VaalinNetwork/Tests/VaalinNetworkTests"
        ),

        // Core package
        .target(
            name: "VaalinCore",
            dependencies: [],
            path: "VaalinCore/Sources/VaalinCore",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "VaalinCoreTests",
            dependencies: ["VaalinCore"],
            path: "VaalinCore/Tests/VaalinCoreTests"
        )
    ]
)
