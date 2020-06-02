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
        .library(
            name: "iAVLPlus",
            targets: ["iAVLPlus"]
        ),
        .library(
            name: "SQLiteNodeDB",
            targets: ["SQLiteNodeDB"]
        ),
    ],
//        .library(
//            name: "FlatBufferNodeDB",
//            targets: ["FlatBufferNodeDB"]),
//        ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: "SwiftAmino", from: "1.0.0"),
        .package(url: "https://github.com/cosmosswift/swift-mint.git", from: "0.3.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "4.0.0"),
        // .package(url: "ObjectBox", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "iAVLPlus",
            dependencies: ["Merkle"]
        ),
        .target(
            name: "SQLiteNodeDB",
            dependencies: ["iAVLPlus", "GRDB"]
        ),
//        .target(
//            name: "FlatBufferNodeDB",
//            dependencies: ["iAVLPlus", "GRDB"]),
        .testTarget(
            name: "iAVLPlusTests",
            dependencies: ["iAVLPlus"]
        ),
        .testTarget(
            name: "SQLiteNodeDBTests",
            dependencies: ["iAVLPlus", "SQLiteNodeDB"]
        ),
//        .testTarget(
//            name: "FlatBufferNodeDBTests",
//            dependencies: ["iAVLPlus", "FlatBufferNodeDB"]),
    ]
)