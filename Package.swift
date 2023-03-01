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
        .package(url: "https://github.com/lunij/swift-package-manager.git", branch: "marc/5.7/error-propagation"),
        .package(url: "https://github.com/apple/swift-tools-support-core.git", branch: "release/5.7")
    ] + .plugins,
    targets: [
        .executableTarget(
            name: "CreateXCFramework",
            dependencies: ["CreateXCFrameworkKit"],
            plugins: .default
        ),
        .target(
            name: "CreateXCFrameworkKit",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftPM-auto", package: "swift-package-manager"),
                .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
            ],
            plugins: .default
        ),
        .testTarget(
            name: "CreateXCFrameworkKitTests",
            dependencies: ["CreateXCFrameworkKit"],
            resources: [
                .copy("Fixtures")
            ],
            plugins: .default
        )
    ],
    swiftLanguageVersions: [
        .v5
    ]
)

extension [PackageDescription.Package.Dependency] {
    static var plugins: [Element] {
        [
            .package(url: "git@github.com:lunij/SwiftFormatPlugin", from: "0.50.7"),
            .package(url: "git@github.com:lunij/SwiftLintPlugin", from: "0.50.3")
        ]
    }
}

extension [Target.PluginUsage] {
    static var `default`: [Element] {
        [
            .plugin(name: "SwiftFormatPrebuildPlugin", package: "SwiftFormatPlugin"),
            .plugin(name: "SwiftLintPrebuildFix", package: "SwiftLintPlugin"),
            .plugin(name: "SwiftLint", package: "SwiftLintPlugin")
        ]
    }
}
