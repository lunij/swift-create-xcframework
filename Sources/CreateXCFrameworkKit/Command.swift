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
            config: package.config,
            packageGraph: package.graph,
            projectName: package.name
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
        let frameworkBuilder = FrameworkBuilder(config: package.config)
        let xcframeworkBuilder = XCFrameworkBuilder(config: package.config)

        return try package
            .filteredLibraryProducts
            .flatMap(\.targets)
            .map { target in
                try frameworkBuilder.buildFrameworks(from: target, sdks: package.platforms.flatMap(\.sdks), project: xcodeProject)
            }
            .map { frameworks in
                try xcframeworkBuilder.buildXCFramework(from: frameworks)
            }
    }
}
