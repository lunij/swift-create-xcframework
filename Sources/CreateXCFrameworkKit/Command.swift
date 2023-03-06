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

        let frameworks = try createFrameworks(from: package, xcodeBacked: config.options.xcodeBacked)
        let xcframeworks = try createXCFrameworks(from: frameworks, config: config)

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

    private func createFrameworks(from package: Package, xcodeBacked: Bool) throws -> [[Framework]] {
        let xcodeProject = xcodeBacked ? try createXcodeProject(from: package) : nil
        let sdks = package.platforms.flatMap(\.sdks)
        let frameworkBuilder = FrameworkBuilder(config: package.config)
        return try package
            .filteredLibraryProducts
            .flatMap(\.targets)
            .map { target in
                if let xcodeProject {
                    return try frameworkBuilder.buildFrameworks(from: target, sdks: sdks, projectType: .xcodeProject(xcodeProject))
                } else {
                    return try frameworkBuilder.buildFrameworks(from: target, sdks: sdks, projectType: .swiftPackage(package))
                }
            }
    }

    private func createXCFrameworks(from frameworks: [[Framework]], config: Config) throws -> [XCFramework] {
        let xcframeworkBuilder = XCFrameworkBuilder(config: config)
        return try frameworks
            .map { frameworks in
                try xcframeworkBuilder.buildXCFramework(from: frameworks)
            }
    }
}
