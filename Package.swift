// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iAVLPlus",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(name: "iAVLPlus", targets: ["iAVLPlusCore", "iAVLPlusLegacy"]),
        .library(name: "InMemoryNodeDB", targets: ["InMemoryNodeDB"]),
//        .library(name: "FlatBufferNodeDB", targets: ["FlatBufferNodeDB"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/cosmosswift/swift-mint.git", from: "0.3.0"),
        // .package(url: "ObjectBox", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(name: "iAVLPlusCore", dependencies: ["Merkle"]),
        .target(name: "iAVLPlusLegacy", dependencies: ["iAVLPlusCore"]),
        .target(name: "InMemoryNodeDB", dependencies: ["iAVLPlusCore"]),
//        .target(name: "FlatBufferNodeDB", dependencies: ["iAVLPlusCore", "GRDB"]),
        .testTarget(name: "iAVLPlusCoreTests", dependencies: ["iAVLPlusCore", "InMemoryNodeDB"]),
        .testTarget(name: "iAVLPlusLegacyTests", dependencies: ["iAVLPlusCore", "iAVLPlusLegacy"]),
//        .testTarget(name: "FlatBufferNodeDBTests", dependencies: ["iAVLPlusCore", "FlatBufferNodeDB"]),
    ]
)
