// swift-tools-version:5.4

import PackageDescription

let package = Package(
    name: "swift-iavlplus",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library(name: "iAVLPlus", targets: ["iAVLPlusCore", "iAVLPlusLegacy"]),
        .library(name: "InMemoryNodeDB", targets: ["InMemoryNodeDB"]),
    ],
    dependencies: [
        .package(name: "swift-mint", url: "https://github.com/cosmosswift/swift-mint.git", .upToNextMajor(from: "0.4.0")),
    ],
    targets: [
        .target(
            name: "iAVLPlusCore",
            dependencies: [
                .product(name: "Merkle", package: "swift-mint"),
            ]
        ),
        .target(name: "iAVLPlusLegacy", dependencies: ["iAVLPlusCore"]),
        .target(name: "InMemoryNodeDB", dependencies: ["iAVLPlusCore"]),
        .testTarget(name: "iAVLPlusCoreTests", dependencies: ["iAVLPlusCore", "InMemoryNodeDB"]),
        .testTarget(name: "iAVLPlusLegacyTests", dependencies: ["iAVLPlusCore", "iAVLPlusLegacy"]),
    ]
)
