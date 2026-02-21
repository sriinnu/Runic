// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Helix",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "Helix", targets: ["Helix"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Helix",
            path: "Sources/Helix",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]),
        .testTarget(
            name: "HelixTests",
            dependencies: ["Helix"],
            path: "Tests/HelixTests"),
    ],
    swiftLanguageModes: [.v6])
