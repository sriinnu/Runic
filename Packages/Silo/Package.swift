// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Silo",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "Silo", targets: ["Silo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.4"),
    ],
    targets: [
        .target(
            name: "Silo",
            dependencies: [
                .product(name: "CryptoSwift", package: "CryptoSwift"),
            ],
            path: "Sources/Silo",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]),
        .testTarget(
            name: "SiloTests",
            dependencies: ["Silo"],
            path: "Tests/SiloTests",
            resources: [
                .copy("Fixtures"),
            ]),
    ],
    swiftLanguageModes: [.v6])
