// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "swift-create-xcframework",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "swift-create-xcframework", targets: ["CreateXCFramework"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.0.3"),
        .package(url: "https://github.com/apple/swift-package-manager.git", branch: "release/5.7"),
        .package(url: "https://github.com/apple/swift-tools-support-core.git", branch: "release/5.7")
    ],
    targets: [
        .executableTarget(name: "CreateXCFramework", dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "SwiftPM-auto", package: "swift-package-manager"),
            .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        ]),
        .testTarget(name: "CreateXCFrameworkTests", dependencies: ["CreateXCFramework"])
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
