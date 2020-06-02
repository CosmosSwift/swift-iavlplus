# iavlplus

![Swift5.2+](https://img.shields.io/badge/Swift-5.2+-blue.svg)
![platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20linux-orange.svg)
![CI](https://github.com/cosmosswift/swift-iavlplus/workflows/CI/badge.svg)

This is a Swift iAVL+ Tree protocols and reference implementations to build Tendermint consensus based blockchain applications.

iAVL+ trees are the core structure to provide state to a CosmosSwift blockchain app.

This is work in progress.

We are using the Go Tendermint codebase as a starting point, and implementing the Swift code in a Swifty way.

Swift version: 5.2.x


## Installation

Requires Swift 5.2.x, on MacOS or a variant of Linux with the Swift 5.2.x toolchain installed.

``` bash
git clone https://github.com/CosmosSwift/swift-iavlplus.git
cd swift-iavlplus
swift build
```

In your `Package.swift` file, add the repository as a dependency as such:
``` swift
import PackageDescription

let package = Package(
    name: "MyiAVLPlusApp",
    products: [
        .executable(name: "MyiAVLPlusApp", targets: ["MyiAVLPlusApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/cosmosswift/swift-iavlplus.git", from: "0.1.0"),
    ],
    targets: [
        .target(name: "MyiAVLPlusApp", dependencies: ["iAVLPlus"]),
    ]
)
```

## Getting Started

0. `import IAVLPlus`

1. Compile and run

## Development

### Development Setup:
* `$ brew install swiftformat swiftlint pre-commit`
* `$ pre-commit install`

### Pre-Commit
* Pre-commit sets up some hooks that are run before ever commit (nomen est omen)
* To run it manually it can be used as `pre-commit run [somefile]` or `pre-commit run --all-files`
* To overrule pre-commit simply add `-n` to your commit command e.g. `git commit -m "Fancy commit message" -n`

### Code, Test, Build, Release:

We make use of GitHub Actions to automate the big junks.

* Coding should preferable happen in feature branches, point to `master`
* On feature branches a basic CI pipeline runs to ensure the basics are ok before merging

## Documentation

The docs for the latest tagged release are always available at [https://github.com/cosmosswift/swift-iavlplus/](https://github.com/cosmosswift/swift-iavlplus/).

## Questions

For bugs or feature requests, file a new [issue](https://github.com/cosmosswift/swift-iavlplus/issues).

For all other support requests, please email [opensource@katalysis.io](mailto:opensource@katalysis.io).

## Changelog

[SemVer](https://semver.org/) changes are documented for each release on the [releases page](https://github.com/cosmosswift/swift-iavlplus/releases).

## Contributing

Check out [CONTRIBUTING.md](https://github.com/cosmosswift/swift-iavlplus/blob/master/CONTRIBUTING.md) for more information on how to help with **CosmosSwift**.

## Contributors

Check out [CONTRIBUTORS.txt](https://github.com/cosmosswift/swift-iavlplus/blob/master/CONTRIBUTORS.txt) to see the full list. This list is updated for each release.
