// swift-tools-version: 6.2
import CompilerPluginSupport
import Foundation
import PackageDescription

// Silo - Browser cookie storage and extraction library
let siloPath = "../Packages/Silo"
let siloDependency: Package.Dependency = FileManager.default.fileExists(atPath: siloPath)
    ? .package(path: siloPath)
    : .package(url: "https://github.com/sriinnu/Silo", from: "1.0.0")

// Helix - Command-line parsing framework
let helixPath = "../Packages/Helix"
let helixDependency: Package.Dependency = FileManager.default.fileExists(atPath: helixPath)
    ? .package(path: helixPath)
    : .package(url: "https://github.com/sriinnu/Helix", from: "1.0.0")

let package = Package(
    name: "Runic",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1"),
        helixDependency,
        .package(url: "https://github.com/apple/swift-log", from: "1.8.0"),
        .package(url: "https://github.com/apple/swift-syntax", from: "600.0.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "1.10.0"),
        siloDependency,
    ],
    targets: {
        var targets: [Target] = [
            .target(
                name: "RunicCore",
                dependencies: [
                    "RunicMacroSupport",
                    .product(name: "Logging", package: "swift-log"),
                    .product(name: "Silo", package: "Silo"),
                ],
                // Sync directory now enabled for iCloud CloudKit synchronization
                // exclude: [
                //     "Sync",
                // ],
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .macro(
                name: "RunicMacros",
                dependencies: [
                    .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                    .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                    .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                ]),
            .target(
                name: "RunicMacroSupport",
                dependencies: [
                    "RunicMacros",
                ]),
            .executableTarget(
                name: "RunicCLI",
                dependencies: [
                    "RunicCore",
                    .product(name: "Helix", package: "Helix"),
                ],
                path: "Sources/RunicCLI",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
        .testTarget(
            name: "RunicLinuxTests",
            dependencies: ["RunicCore", "RunicCLI"],
            path: "TestsLinux",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ]),
        ]

        #if os(macOS)
        targets.append(contentsOf: [
            .executableTarget(
                name: "RunicClaudeWatchdog",
                dependencies: [],
                path: "Sources/RunicClaudeWatchdog",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .executableTarget(
                name: "Runic",
                dependencies: [
                    .product(name: "Sparkle", package: "Sparkle"),
                    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                    "RunicMacroSupport",
                    "RunicCore",
                ],
                path: "Sources/Runic",
                resources: [
                    .copy("Resources"),
                ],
                swiftSettings: [
                    // Opt into Swift 6 strict concurrency (approachable migration path).
                    .enableUpcomingFeature("StrictConcurrency"),
                    .define("ENABLE_SPARKLE"),
                ]),
            .executableTarget(
                name: "RunicWidget",
                dependencies: ["RunicCore"],
                path: "Sources/RunicWidget",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .executableTarget(
                name: "RunicClaudeWebProbe",
                dependencies: ["RunicCore"],
                path: "Sources/RunicClaudeWebProbe",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
        ])

        targets.append(.testTarget(
            name: "RunicTests",
            dependencies: ["Runic", "RunicCore", "RunicCLI"],
            path: "Tests",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ]))
        #endif

        return targets
    }())
