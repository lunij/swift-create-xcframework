// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "FixturePackage",
    products: [
        .library(name: "FixtureLibrary", targets: ["FixtureTarget"])
    ],
    targets: [
        .target(name: "FixtureTarget"),
        .binaryTarget(name: "BinaryTarget", path: "BinaryTarget.zip")
    ]
)
