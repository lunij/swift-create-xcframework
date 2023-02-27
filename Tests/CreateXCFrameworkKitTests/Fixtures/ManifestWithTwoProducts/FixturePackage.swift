// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "FixturePackage",
    products: [
        .library(name: "FixtureLibrary1", targets: ["FixtureTarget1"]),
        .library(name: "FixtureLibrary2", targets: ["FixtureTarget2"])
    ],
    targets: [
        .target(name: "FixtureTarget1"),
        .target(name: "FixtureTarget2")
    ]
)
