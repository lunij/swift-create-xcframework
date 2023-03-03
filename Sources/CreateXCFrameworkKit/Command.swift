import ArgumentParser
import Foundation
import TSCBasic

public struct Command: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Creates an XCFramework out of a Swift Package using xcodebuild",
        discussion:
        """
        Note that Swift Binary Frameworks (XCFramework) support is only available in Swift 5.1
        or newer, and so it is only supported by recent versions of Xcode and the *OS SDKs. Likewise,
        only Apple platforms are supported.

        Supported platforms: \(Platform.allCases.map(\.rawValue).joined(separator: ", "))
        """,
        version: "2.3.0"
    )

    @OptionGroup()
    public var options: Options

    public init() {}

    public func run() throws {
        if options.verbose {
            logger = Logger(level: .verbose)
        }

        let config = Config(options: options)
        let package = try Package(config: config)

        if options.listProducts {
            return package.listProducts()
        }

        let xcodeProject = try createXcodeProject(from: package)
        let xcframeworks = try createXCFrameworks(from: package, xcodeProject: xcodeProject)

        if options.zip {
            let zipper = Zipper(package: package)
            let zipped = try xcframeworks.flatMap { xcframework -> [URL] in
                let zip = try zipper.zip(target: xcframework.name, version: self.options.zipVersion, file: xcframework.url)
                let checksum = try zipper.checksum(file: zip)
                try zipper.clean(file: xcframework.url)
                return [zip, checksum]
            }

            if options.githubAction {
                let zips = zipped.map(\.path).joined(separator: "\n")
                let data = Data(zips.utf8)
                let url = URL(fileURLWithPath: options.buildPath).appendingPathComponent("xcframework-zipfile.url")
                try data.write(to: url)
            }
        }
    }

    private func createXcodeProject(from package: Package) throws -> XcodeProject {
        logger.info("Generating Xcode project")

        let generator = XcodeProjectGenerator(
            projectName: package.name,
            config: package.config,
            packageGraph: package.graph
        )
        let xcodeProject = try generator.generate()

        // we've applied the xcconfig to everything, but some dependencies (*cough* swift-nio)
        // have build errors, so we remove it from targets we're not building
        if options.stackEvolution == false {
            xcodeProject.enableDistribution(
                targets: package.filteredLibraryProducts.flatMap(\.targets),
                xcconfig: AbsolutePath(package.config.distributionBuildXcconfig.path).relative(to: AbsolutePath(package.config.packageDirectory.path))
            )
        }

        try xcodeProject.save()
        return xcodeProject
    }

    private func createXCFrameworks(from package: Package, xcodeProject: XcodeProject) throws -> [XCFramework] {
        let builder = XcodeBuilder(project: xcodeProject, config: package.config)

        if options.clean {
            try builder.clean()
        }

        return try package
            .filteredLibraryProducts
            .flatMap(\.targets)
            .map { target in
                let frameworks = try builder.createFrameworks(from: target, sdks: package.platforms.flatMap(\.sdks))
                return try builder.createXCFramework(from: frameworks)
            }
    }
}

private extension XcodeBuilder {
    func createFrameworks(from target: String, sdks: [Platform.SDK]) throws -> [Framework] {
        try sdks.map { sdk in
            try build(target: target, sdk: sdk)
        }
    }
}
